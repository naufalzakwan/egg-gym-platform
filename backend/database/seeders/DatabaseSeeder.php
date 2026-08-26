<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            AdminUserSeeder::class,
            MembershipPlanSeeder::class,
            MemberProfileSeeder::class,
            TrainerProfileSeeder::class,
            EquipmentSeeder::class,
            GymOperationHourSeeder::class,
            TransactionSeeder::class,
            BookingSeeder::class,
        ]);
    }
}
