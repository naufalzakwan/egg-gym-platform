<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\MembershipPaymentMethod;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberPaymentCheckoutTest extends TestCase
{
    use DatabaseTransactions;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_checkout_converts_provider_utc_expiry_before_persisting(): void
    {
        $now = CarbonImmutable::parse('2026-07-21T16:04:14+07:00');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);

        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => 'Payment Checkout Member',
            'email' => uniqid('payment_checkout_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid('PAY-'),
        ]);
        $plan = MembershipPlan::create([
            'name' => 'Checkout Timezone Plan',
            'slug' => uniqid('checkout-timezone-'),
            'price' => 549000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => [],
            'is_active' => true,
        ]);

        Http::fake([
            '*/api/transactioncreate/bri_va' => Http::response([
                'payment' => [
                    'order_id' => 'provider-order',
                    'payment_number' => '1234567890',
                    'fee' => 5490,
                    'total_payment' => 554490,
                    'expired_at' => '2026-07-21T10:34:14.000000000Z',
                ],
            ]),
        ]);
        Sanctum::actingAs($user, [], 'sanctum');

        $response = $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $plan->id,
            'payment_method' => 'bri_va',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.transaction.status', 'pending')
            ->assertJsonPath('data.checkout.provider_method', 'bri_va')
            ->assertJsonPath('data.checkout.expired_at', '2026-07-21T17:34:14+07:00');

        $transaction = Transaction::query()
            ->where('member_profile_id', $member->id)
            ->latest('id')
            ->firstOrFail();

        $this->assertSame('pending', $transaction->status);
        $this->assertSame('2026-07-21T17:34:14+07:00', $transaction->expired_at->toIso8601String());

        $this->getJson('/api/v1/member/transactions')
            ->assertOk()
            ->assertJsonPath('data.0.status', 'pending')
            ->assertJsonPath('data.0.is_expired', false)
            ->assertJsonPath('data.0.remaining_seconds', 5400);

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'status' => 'pending',
            'expired_at' => '2026-07-21 17:34:14',
        ]);
    }

    public function test_inactive_method_blocks_new_checkout_but_does_not_damage_pending_transaction(): void
    {
        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => 'Inactive Method Member',
            'email' => uniqid('inactive_method_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create(['user_id' => $user->id, 'member_code' => uniqid('INACTIVE-')]);
        $plan = MembershipPlan::create([
            'name' => 'Inactive Method Plan',
            'slug' => uniqid('inactive-method-'),
            'price' => 100000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => [],
            'is_active' => true,
        ]);
        $pending = Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => uniqid('PENDING-INACTIVE-'),
            'title' => 'Pending before disable',
            'payment_method' => 'qris',
            'amount' => 100000,
            'fee' => 1000,
            'total_payment' => 101000,
            'status' => 'pending',
            'payment_number' => 'QR-PENDING-OLD',
            'expired_at' => now()->addHour(),
        ]);
        MembershipPaymentMethod::query()->where('provider_code', 'qris')->update(['is_active' => false]);
        Sanctum::actingAs($user, [], 'sanctum');
        Http::fake();

        $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $plan->id,
            'payment_method' => 'qris',
        ])->assertUnprocessable()->assertJsonPath('message', 'Metode pembayaran sedang tidak tersedia.');
        Http::assertNothingSent();

        $this->getJson('/api/v1/member/transactions')->assertOk()
            ->assertJsonPath('data.0.reference_code', $pending->reference_code)
            ->assertJsonPath('data.0.payment_number', 'QR-PENDING-OLD')
            ->assertJsonPath('data.0.status', 'pending');
        $this->assertSame('pending', $pending->fresh()->status);
    }
}
