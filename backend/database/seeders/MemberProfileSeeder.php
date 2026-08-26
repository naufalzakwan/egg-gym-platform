<?php

namespace Database\Seeders;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class MemberProfileSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $memberRole = Role::where('name', 'member')->first();
        $plan = MembershipPlan::where('slug', 'elite-member')->first();

        if (! $memberRole || ! $plan) {
            return;
        }

        $user = User::updateOrCreate(
            ['email' => 'member@egggym.com'],
            [
                'role_id' => $memberRole->id,
                'name' => 'EggGym Member Demo',
                'phone' => '081234567804',
                'password' => Hash::make('member12345'),
                'status' => 'active',
                'avatar_url' => null,
            ]
        );

        $memberProfile = MemberProfile::updateOrCreate(
            ['user_id' => $user->id],
            [
                'member_code' => 'MEM-0001',
                'gender' => 'male',
                'birth_date' => '2001-08-17',
                'height_cm' => 175.0,
                'weight_kg' => 79.8,
                'fitness_goal' => 'Muscle gain',
                'medical_note' => null,
                'joined_at' => now()->subMonths(3),
            ]
        );

        MemberMembership::updateOrCreate(
            [
                'member_profile_id' => $memberProfile->id,
                'membership_plan_id' => $plan->id,
            ],
            [
                'start_date' => now()->subDays(20)->toDateString(),
                'end_date' => now()->addDays(142)->toDateString(),
                'status' => 'active',
                'payment_status' => 'paid',
            ]
        );
    }
}
