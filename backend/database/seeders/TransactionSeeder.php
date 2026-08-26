<?php

namespace Database\Seeders;

use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Transaction;
use Illuminate\Database\Seeder;

class TransactionSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $memberProfile = MemberProfile::where('member_code', 'MEM-0001')->first();
        $plan = MembershipPlan::where('slug', 'elite-member')->first();

        if (! $memberProfile || ! $plan) {
            return;
        }

        $transactions = [
            [
                'member_profile_id' => $memberProfile->id,
                'membership_plan_id' => $plan->id,
                'reference_code' => 'TRX-20260509-0001',
                'title' => 'Elite Membership - Sep',
                'payment_method' => 'qris',
                'amount' => 549000,
                'status' => 'paid',
                'paid_at' => now()->subDays(7),
                'provider_reference' => 'PKS-92827372',
            ],
        ];

        foreach ($transactions as $transaction) {
            Transaction::updateOrCreate(
                ['reference_code' => $transaction['reference_code']],
                $transaction
            );
        }
    }
}
