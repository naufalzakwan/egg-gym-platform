<?php

namespace Database\Seeders;

use App\Models\GymOperationHour;
use Illuminate\Database\Seeder;

class GymOperationHourSeeder extends Seeder
{
    public function run(): void
    {
        $hours = [
            ['day_name' => 'Monday', 'day_order' => 1, 'open_time' => '07:00:00', 'close_time' => '21:30:00', 'is_closed' => false],
            ['day_name' => 'Tuesday', 'day_order' => 2, 'open_time' => '07:00:00', 'close_time' => '21:30:00', 'is_closed' => false],
            ['day_name' => 'Wednesday', 'day_order' => 3, 'open_time' => '07:00:00', 'close_time' => '21:30:00', 'is_closed' => false],
            ['day_name' => 'Thursday', 'day_order' => 4, 'open_time' => '07:00:00', 'close_time' => '21:30:00', 'is_closed' => false],
            ['day_name' => 'Friday', 'day_order' => 5, 'open_time' => '07:00:00', 'close_time' => '21:00:00', 'is_closed' => false],
            ['day_name' => 'Saturday', 'day_order' => 6, 'open_time' => '07:00:00', 'close_time' => '21:00:00', 'is_closed' => false],
            ['day_name' => 'Sunday', 'day_order' => 7, 'open_time' => null, 'close_time' => null, 'is_closed' => true],
        ];

        foreach ($hours as $hour) {
            GymOperationHour::updateOrCreate(
                ['day_order' => $hour['day_order']],
                $hour,
            );
        }
    }
}
