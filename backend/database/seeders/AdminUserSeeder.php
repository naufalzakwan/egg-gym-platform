<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $adminRole = Role::where('name', 'admin')->first();

        if (! $adminRole) {
            return;
        }

        User::updateOrCreate(
            ['email' => 'admin@egggym.com'],
            [
                'role_id' => $adminRole->id,
                'name' => 'EggGym Admin',
                'phone' => '081234567890',
                'password' => Hash::make('admin12345'),
                'status' => 'active',
                'is_admin_owner' => true,
            ]
        );
    }
}
