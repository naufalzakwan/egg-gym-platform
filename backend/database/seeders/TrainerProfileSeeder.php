<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class TrainerProfileSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $trainerRole = Role::where('name', 'trainer')->first();

        if (! $trainerRole) {
            return;
        }

        $trainers = [
            [
                'user' => [
                    'name' => 'Coach Adrian Putra',
                    'email' => 'adrian@egggym.com',
                    'phone' => '081234567801',
                    'password' => Hash::make('trainer12345'),
                    'status' => 'active',
                    'avatar_url' => null,
                ],
                'profile' => [
                    'specialty' => 'Bodybuilding - Nutrition',
                    'rating' => 0,
                ],
            ],
            [
                'user' => [
                    'name' => 'Coach Elena Rodriguez',
                    'email' => 'elena@egggym.com',
                    'phone' => '081234567802',
                    'password' => Hash::make('trainer12345'),
                    'status' => 'active',
                    'avatar_url' => null,
                ],
                'profile' => [
                    'specialty' => 'Yoga - Flexibility',
                    'rating' => 0,
                ],
            ],
            [
                'user' => [
                    'name' => 'Coach Julian Vane',
                    'email' => 'julian@egggym.com',
                    'phone' => '081234567803',
                    'password' => Hash::make('trainer12345'),
                    'status' => 'active',
                    'avatar_url' => null,
                ],
                'profile' => [
                    'specialty' => 'Muscle Gain',
                    'rating' => 0,
                ],
            ],
        ];

        foreach ($trainers as $trainer) {
            $user = User::updateOrCreate(
                ['email' => $trainer['user']['email']],
                [
                    'role_id' => $trainerRole->id,
                    'name' => $trainer['user']['name'],
                    'phone' => $trainer['user']['phone'],
                    'password' => $trainer['user']['password'],
                    'status' => $trainer['user']['status'],
                    'avatar_url' => $trainer['user']['avatar_url'],
                ]
            );

            TrainerProfile::updateOrCreate(
                ['user_id' => $user->id],
                $trainer['profile']
            );
        }
    }
}
