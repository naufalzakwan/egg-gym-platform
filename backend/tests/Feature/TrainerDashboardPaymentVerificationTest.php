<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerDashboardPaymentVerificationTest extends TestCase
{
    use DatabaseTransactions;

    public function test_payment_uploaded_is_a_separate_request_and_not_a_today_session(): void
    {
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Dashboard Payment Trainer',
            'email' => uniqid('dashboard_payment_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Strength',
            'price_per_session' => 150000,
        ]);
        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Dashboard Payment Member',
            'email' => uniqid('dashboard_payment_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('DASH-PAY-'),
            'fitness_goal' => 'Strength',
        ]);
        $today = now()->toDateString();
        $scheduleDate = TrainerScheduleDate::create([
            'trainer_profile_id' => $trainer->id,
            'schedule_date' => $today,
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);

        $uploaded = $this->createBooking($member, $trainer, $today, 'payment_uploaded', '08:00:00');
        $uploaded->update([
            'payment_proof_path' => 'booking-payments/proof.jpg',
            'payment_proof_uploaded_at' => now(),
            'expired_at' => now()->subMinute(),
        ]);
        $verified = $this->createBooking($member, $trainer, $today, 'payment_verified', '10:00:00');
        $verified->update(['payment_verified_at' => now()]);
        $this->createBooking($member, $trainer, $today, 'waiting_payment', '12:00:00');
        $unpaidRescheduled = $this->createBooking($member, $trainer, $today, 'rescheduled', '14:00:00');
        $paidRescheduled = $this->createBooking($member, $trainer, $today, 'rescheduled', '16:00:00');
        $paidRescheduled->update(['payment_verified_at' => now()]);

        $childToday = $this->createBooking(
            $member,
            $trainer,
            now()->addDay()->toDateString(),
            'payment_verified',
            '18:00:00'
        );
        $childToday->update(['payment_verified_at' => now()]);
        BookingSessionReservation::create([
            'booking_id' => $childToday->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => $today,
            'start_time' => '18:00:00',
            'end_time' => '19:00:00',
            'session_duration_minutes' => 60,
            'status' => 'reserved',
        ]);

        Sanctum::actingAs($trainerUser, [], 'sanctum');
        $response = $this->getJson('/api/v1/trainer/dashboard')
            ->assertOk()
            ->assertJsonPath('data.today_sessions', 3)
            ->assertJsonCount(3, 'data.today_agenda')
            ->assertJsonCount(1, 'data.payment_verification_requests')
            ->assertJsonPath('data.payment_verification_requests.0.id', $uploaded->id)
            ->assertJsonPath('data.payment_verification_requests.0.status', 'payment_uploaded')
            ->assertJsonPath('data.payment_verification_requests.0.is_payment_verification_overdue', true);

        $agendaIds = collect($response->json('data.today_agenda'))->pluck('id')->all();
        $this->assertContains($verified->id, $agendaIds);
        $this->assertContains($paidRescheduled->id, $agendaIds);
        $this->assertContains($childToday->id, $agendaIds);
        $this->assertNotContains($uploaded->id, $agendaIds);
        $this->assertNotContains($unpaidRescheduled->id, $agendaIds);
    }

    private function createBooking(
        MemberProfile $member,
        TrainerProfile $trainer,
        string $date,
        string $status,
        string $startTime
    ): Booking {
        return Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'session_title' => 'Dashboard '.$status,
            'session_date' => $date,
            'start_time' => $startTime,
            'end_time' => date('H:i:s', strtotime($startTime.' +1 hour')),
            'session_duration_minutes' => 60,
            'location' => 'Egg Gym',
            'status' => $status,
        ]);
    }
}
