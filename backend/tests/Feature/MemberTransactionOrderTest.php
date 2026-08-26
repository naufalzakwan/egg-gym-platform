<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberTransactionOrderTest extends TestCase
{
    use DatabaseTransactions;

    public function test_member_transactions_are_created_at_newest_first_for_all_statuses(): void
    {
        $role = Role::query()->firstOrCreate(['name' => 'member']);
        $user = User::query()->create([
            'role_id' => $role->id,
            'name' => 'Transaction Order Member',
            'email' => uniqid('transaction_order_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::query()->create([
            'user_id' => $user->id,
            'member_code' => uniqid('TX-ORDER-'),
        ]);

        $oldPlan = $this->plan('Starter Pack');
        $middlePlan = $this->plan('Annual Pro');
        $newPlan = $this->plan('Elite Member');
        $old = $this->transaction($member, $oldPlan, 'Wrong old title', 'completed', '2026-07-21 09:00:00', '2026-07-26 09:00:00');
        $middle = $this->transaction($member, $middlePlan, 'Wrong middle title', 'completed', '2026-07-22 09:00:00', '2026-07-27 09:00:00');
        $new = $this->transaction($member, $newPlan, 'Wrong newest title', 'pending', '2026-07-26 09:00:00');
        $supplement = Transaction::query()->create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => null,
            'reference_code' => uniqid('PRODUCT-'),
            'title' => 'Protein Supplement Kit',
            'payment_method' => 'qris',
            'amount' => 425000,
            'status' => 'completed',
        ]);
        $supplement->forceFill(['created_at' => '2026-07-27 09:00:00'])->saveQuietly();
        $oldPlan->delete();

        Sanctum::actingAs($user, [], 'sanctum');

        $this->getJson('/api/v1/member/transactions')
            ->assertOk()
            ->assertJsonPath('data.0.id', $new->id)
            ->assertJsonPath('data.0.title', 'Elite Member')
            ->assertJsonPath('data.0.type', 'membership')
            ->assertJsonPath('data.1.id', $middle->id)
            ->assertJsonPath('data.1.title', 'Annual Pro')
            ->assertJsonPath('data.2.id', $old->id)
            ->assertJsonPath('data.2.title', 'Starter Pack')
            ->assertJsonCount(3, 'data');
    }

    private function transaction(
        MemberProfile $member,
        MembershipPlan $plan,
        string $title,
        string $status,
        string $createdAt,
        ?string $paidAt = null
    ): Transaction {
        $transaction = Transaction::query()->create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => uniqid('TX-ORDER-'),
            'title' => $title,
            'payment_method' => 'qris',
            'amount' => 100000,
            'status' => $status,
            'paid_at' => $paidAt,
            'expired_at' => $status === 'pending' ? now()->addHour() : null,
        ]);
        $transaction->forceFill([
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ])->saveQuietly();

        return $transaction;
    }

    private function plan(string $name): MembershipPlan
    {
        return MembershipPlan::query()->create([
            'name' => $name,
            'slug' => uniqid('membership-plan-'),
            'price' => 100000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
    }
}
