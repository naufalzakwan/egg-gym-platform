<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\TrainingProgramSessionExercise;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerProgramActiveFlowTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainerProfile $trainer;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();

        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Active Flow Trainer',
            'email' => uniqid('active_flow_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Active flow testing',
        ]);
        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Active Flow Member',
            'email' => uniqid('active_flow_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('ACTIVE-'),
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
    }

    public function test_future_reserved_program_is_active_and_returns_authoritative_summary(): void
    {
        $booking = $this->booking([
            'session_date' => '2030-08-15',
            'start_time' => '10:00:00',
            'end_time' => '11:30:00',
        ]);
        $program = $this->program($booking);
        $later = $this->programSession($program, 2, 45);
        $next = $this->programSession($program, 1, 60);
        $this->reservation($booking, $later, 2, '2030-08-22');
        $this->reservation($booking, $next, 1, '2030-08-15');
        foreach (range(1, 3) as $sequence) {
            TrainingProgramSessionExercise::create([
                'training_program_session_id' => $next->id,
                'sequence_order' => $sequence,
                'custom_name' => 'Exercise '.$sequence,
                'sets' => 3,
                'reps' => 10,
            ]);
        }

        $response = $this->getJson('/api/v1/trainer/programs')->assertOk();

        $response
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.is_active_control', true)
            ->assertJsonPath('data.0.total_duration_minutes', 105)
            ->assertJsonPath('data.0.exercises_count', 3)
            ->assertJsonPath('data.0.next_session.session_date', '2030-08-15')
            ->assertJsonPath('data.0.next_session.start', '10:00:00')
            ->assertJsonPath('data.0.next_session.end', '11:30:00')
            ->assertJsonPath('data.0.next_session.status', 'reserved');
    }

    public function test_ineligible_booking_reservation_and_program_states_remain_listed_but_inactive(): void
    {
        $unverified = $this->program($this->booking(['payment_verified_at' => null]));
        $this->programSession($unverified);

        $terminalBooking = $this->program($this->booking(['status' => 'completed']));
        $this->programSession($terminalBooking);

        $releasedBooking = $this->booking();
        $released = $this->program($releasedBooking);
        $releasedSession = $this->programSession($released);
        $this->reservation($releasedBooking, $releasedSession, 1, '2030-09-01', 'released');

        $completed = $this->program();
        $this->programSession($completed, status: 'completed');

        $closed = $this->program(status: 'closed_early');
        $this->programSession($closed);

        $data = collect($this->getJson('/api/v1/trainer/programs')->assertOk()->json('data'))
            ->keyBy('id');

        $this->assertCount(5, $data);
        foreach ([$unverified, $terminalBooking, $released, $completed, $closed] as $program) {
            $this->assertFalse($data[$program->id]['is_active_control']);
        }
    }

    public function test_program_list_is_scoped_to_authenticated_trainer(): void
    {
        $owned = $this->program($this->booking());
        $this->programSession($owned);

        $otherUser = User::create([
            'role_id' => Role::firstOrCreate(['name' => 'trainer'])->id,
            'name' => 'Other Active Flow Trainer',
            'email' => uniqid('other_active_flow_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $otherTrainer = TrainerProfile::create([
            'user_id' => $otherUser->id,
            'specialty' => 'Ownership testing',
        ]);
        $otherProgram = TrainingProgram::create([
            'trainer_profile_id' => $otherTrainer->id,
            'member_profile_id' => $this->member->id,
            'title' => 'Other Trainer Program',
            'status' => 'active',
        ]);
        $this->programSession($otherProgram);

        $this->getJson('/api/v1/trainer/programs')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $owned->id);
    }

    private function booking(array $overrides = []): Booking
    {
        return Booking::create(array_merge([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Active Flow Booking',
            'session_date' => '2030-09-01',
            'start_time' => '08:00:00',
            'end_time' => '09:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio A',
            'session_count' => 2,
            'status' => 'confirmed',
            'payment_verified_at' => now(),
        ], $overrides));
    }

    private function program(?Booking $booking = null, string $status = 'active'): TrainingProgram
    {
        return TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $booking?->id,
            'title' => 'Active Flow Program '.uniqid(),
            'status' => $status,
        ]);
    }

    private function programSession(
        TrainingProgram $program,
        int $sequence = 1,
        int $duration = 60,
        string $status = 'active'
    ): TrainingProgramSession {
        return TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'sequence_order' => $sequence,
            'title' => 'Session '.$sequence,
            'duration_minutes' => $duration,
            'status' => $status,
        ]);
    }

    private function reservation(
        Booking $booking,
        TrainingProgramSession $session,
        int $sequence,
        string $date,
        string $status = BookingSessionReservation::STATUS_RESERVED
    ): BookingSessionReservation {
        $scheduleDate = TrainerScheduleDate::firstOrCreate(
            [
                'trainer_profile_id' => $this->trainer->id,
                'schedule_date' => $date,
            ],
            [
                'state' => 'open',
                'source' => 'manual',
                'lock_version' => 1,
            ]
        );
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => $sequence,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => $date,
            'start_time' => $sequence === 1 ? '10:00:00' : '12:00:00',
            'end_time' => $sequence === 1 ? '11:30:00' : '13:00:00',
            'session_duration_minutes' => $sequence === 1 ? 90 : 60,
            'status' => $status,
        ]);
        $session->update(['booking_session_reservation_id' => $reservation->id]);

        return $reservation;
    }
}
