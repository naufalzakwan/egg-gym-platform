<?php

namespace Database\Seeders;

use App\Models\Booking;
use App\Models\MemberProfile;
use App\Models\TrainerProfile;
use Illuminate\Database\Seeder;

class BookingSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $memberProfile = MemberProfile::where('member_code', 'MEM-0001')->first();
        $trainerProfile = TrainerProfile::whereHas('user', function ($query) {
            $query->where('email', 'elena@egggym.com');
        })->first();

        if (! $memberProfile || ! $trainerProfile) {
            return;
        }

        $bookings = [
            [
                'member_profile_id' => $memberProfile->id,
                'trainer_profile_id' => $trainerProfile->id,
                'session_title' => 'Upper Body Hypertrophy',
                'session_date' => now()->addDays(2)->toDateString(),
                'start_time' => '17:00:00',
                'end_time' => '18:30:00',
                'session_duration_minutes' => 90,
                'location' => 'Studio A',
                'status' => 'confirmed',
                'member_note' => 'Fokus back dan rear delt',
                'trainer_note' => 'Jaga tempo negatif dan scapular control',
            ],
            [
                'member_profile_id' => $memberProfile->id,
                'trainer_profile_id' => $trainerProfile->id,
                'session_title' => 'Mobility Reset Session',
                'session_date' => now()->addDays(5)->toDateString(),
                'start_time' => '08:00:00',
                'end_time' => '09:00:00',
                'session_duration_minutes' => 60,
                'location' => 'Recovery Zone',
                'status' => 'pending',
                'member_note' => 'Butuh sesi ringan setelah leg day',
                'trainer_note' => null,
            ],
        ];

        foreach ($bookings as $booking) {
            Booking::updateOrCreate(
                [
                    'member_profile_id' => $booking['member_profile_id'],
                    'trainer_profile_id' => $booking['trainer_profile_id'],
                    'session_title' => $booking['session_title'],
                    'session_date' => $booking['session_date'],
                ],
                $booking
            );
        }
    }
}
