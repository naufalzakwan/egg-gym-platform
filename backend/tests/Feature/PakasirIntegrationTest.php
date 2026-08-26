<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PakasirIntegrationTest extends TestCase
{
    use DatabaseTransactions;

    private User $user;
    private MemberProfile $member;
    private MembershipPlan $plan;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.pakasir.project' => 'egg-gym-test',
            'services.pakasir.api_key' => 'pakasir-test-key',
            'services.pakasir.base_url' => 'https://pakasir.test',
        ]);
        $role = Role::firstOrCreate(['name' => 'member']);
        $this->user = User::create([
            'role_id' => $role->id,
            'name' => 'Pakasir Integration Member',
            'email' => uniqid('pakasir_integration_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $this->user->id,
            'member_code' => uniqid('PAK-'),
        ]);
        $this->plan = MembershipPlan::create([
            'name' => 'Pakasir Integration Plan',
            'slug' => uniqid('pakasir-plan-'),
            'price' => 300000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => [],
            'is_active' => true,
        ]);
        Sanctum::actingAs($this->user, [], 'sanctum');
    }

    public function test_qris_and_virtual_account_checkout_persist_provider_instructions(): void
    {
        Http::fake([
            '*/api/transactioncreate/qris' => Http::response([
                'payment' => $this->providerPayment('qris-order', 'QR-CONTENT'),
            ]),
            '*/api/transactioncreate/bri_va' => Http::response([
                'payment' => $this->providerPayment('va-order', '1234567890'),
            ]),
        ]);

        $qris = $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $this->plan->id,
            'payment_method' => 'qris',
        ])->assertCreated()
            ->assertJsonPath('data.checkout.provider_method', 'qris')
            ->assertJsonPath('data.checkout.qr_string', 'QR-CONTENT');
        $va = $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $this->plan->id,
            'payment_method' => 'bri_va',
        ])->assertCreated()
            ->assertJsonPath('data.checkout.provider_method', 'bri_va')
            ->assertJsonPath('data.checkout.payment_code', '1234567890');

        $this->assertDatabaseHas('transactions', [
            'reference_code' => $qris->json('data.transaction.reference_code'),
            'payment_method' => 'qris',
            'status' => 'pending',
        ]);
        $this->assertDatabaseHas('transactions', [
            'reference_code' => $va->json('data.transaction.reference_code'),
            'payment_method' => 'bri_va',
            'status' => 'pending',
        ]);
    }

    public function test_verified_webhook_fulfills_membership_once(): void
    {
        $transaction = $this->pendingTransaction('WEBHOOK-VALID');
        Http::fake([
            '*/api/transactiondetail*' => Http::response([
                'transaction' => [
                    'project' => 'egg-gym-test',
                    'order_id' => $transaction->reference_code,
                    'amount' => 300000,
                    'status' => 'completed',
                    'payment_method' => 'qris',
                    'completed_at' => '2026-07-29T06:00:00Z',
                ],
            ]),
        ]);
        $payload = $this->webhookPayload($transaction);

        $this->postJson('/api/v1/public/payments/pakasir/webhook', $payload)
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');
        $this->postJson('/api/v1/public/payments/pakasir/webhook', $payload)
            ->assertOk()
            ->assertJsonPath('message', 'Webhook Pakasir sudah pernah diproses.');

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'status' => 'completed',
            'provider_name' => 'pakasir',
        ]);
        $this->assertSame(1, MemberMembership::query()
            ->where('member_profile_id', $this->member->id)
            ->where('membership_plan_id', $this->plan->id)
            ->count());
    }

    public function test_webhook_rejects_project_amount_and_verified_detail_mismatch(): void
    {
        $transaction = $this->pendingTransaction('WEBHOOK-MISMATCH');

        $this->postJson('/api/v1/public/payments/pakasir/webhook', [
            ...$this->webhookPayload($transaction),
            'project' => 'other-project',
        ])->assertUnprocessable();
        $this->postJson('/api/v1/public/payments/pakasir/webhook', [
            ...$this->webhookPayload($transaction),
            'amount' => 299999,
        ])->assertUnprocessable();

        Http::fake([
            '*/api/transactiondetail*' => Http::response([
                'transaction' => [
                    'project' => 'egg-gym-test',
                    'order_id' => 'different-order',
                    'amount' => 300000,
                    'status' => 'completed',
                ],
            ]),
        ]);
        $this->postJson('/api/v1/public/payments/pakasir/webhook', $this->webhookPayload($transaction))
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Verifikasi detail transaksi Pakasir tidak cocok.');

        $this->assertSame('pending', $transaction->fresh()->status);
        $this->assertSame(0, MemberMembership::query()
            ->where('member_profile_id', $this->member->id)
            ->count());
    }

    public function test_cancel_expire_and_regenerate_keep_transaction_history(): void
    {
        $cancelled = $this->pendingTransaction('CANCEL-ME');
        $this->postJson("/api/v1/member/payments/{$cancelled->reference_code}/cancel")
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
        $this->assertDatabaseHas('transactions', [
            'id' => $cancelled->id,
            'status' => 'cancelled',
        ]);

        $expired = $this->pendingTransaction('REGENERATE-ME', now()->subMinute());
        Http::fake([
            '*/api/transactioncreate/qris' => Http::response([
                'payment' => $this->providerPayment('regenerated-order', 'NEW-QR'),
            ]),
        ]);
        $response = $this->postJson("/api/v1/member/payments/{$expired->reference_code}/regenerate")
            ->assertCreated()
            ->assertJsonPath('data.checkout.qr_string', 'NEW-QR');

        $this->assertDatabaseHas('transactions', [
            'id' => $expired->id,
            'status' => 'expired',
        ]);
        $this->assertDatabaseHas('transactions', [
            'reference_code' => $response->json('data.transaction.reference_code'),
            'status' => 'pending',
        ]);
    }

    private function providerPayment(string $orderId, string $paymentNumber): array
    {
        return [
            'order_id' => $orderId,
            'payment_number' => $paymentNumber,
            'fee' => 3000,
            'total_payment' => 303000,
            'expired_at' => CarbonImmutable::now()->addHour()->utc()->toIso8601String(),
        ];
    }

    private function pendingTransaction(
        string $reference,
        $expiredAt = null
    ): Transaction {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'reference_code' => $reference,
            'title' => 'Pakasir integration checkout',
            'payment_method' => 'qris',
            'amount' => 300000,
            'status' => 'pending',
            'provider_name' => 'pakasir',
            'payment_number' => 'OLD-QR',
            'expired_at' => $expiredAt ?? now()->addHour(),
        ]);
    }

    private function webhookPayload(Transaction $transaction): array
    {
        return [
            'amount' => 300000,
            'order_id' => $transaction->reference_code,
            'project' => 'egg-gym-test',
            'status' => 'completed',
            'payment_method' => 'qris',
            'completed_at' => '2026-07-29T06:00:00Z',
        ];
    }
}
