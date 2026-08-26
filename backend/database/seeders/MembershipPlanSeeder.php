<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class MembershipPlanSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $plans = [
            [
                'name' => 'Starter Pack',
                'slug' => 'starter-pack',
                'description' => null,
                'price' => 299000,
                'billing_period' => 'monthly',
                'features_json' => json_encode([
                    'Gym access',
                    'Locker access',
                    'Basic trainer guidance',
                ]),
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Elite Member',
                'slug' => 'elite-member',
                'description' => null,
                'price' => 549000,
                'billing_period' => 'monthly',
                'features_json' => json_encode([
                    'Full gym access',
                    'Sauna access',
                    'Smoothie bar',
                    'Priority private class',
                ]),
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'Annual Pro',
                'slug' => 'annual-pro',
                'description' => null,
                'price' => 1900000,
                'billing_period' => 'yearly',
                'features_json' => json_encode([
                    'Full gym access',
                    'Premium facility access',
                    'Annual savings package',
                ]),
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ];

        foreach ($plans as $plan) {
            DB::table('membership_plans')->updateOrInsert(
                ['slug' => $plan['slug']],
                $plan
            );
        }
    }
}
