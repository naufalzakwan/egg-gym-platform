<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\SelfTrainingExercise;
use App\Models\SelfTrainingProgram;
use App\Models\SelfTrainingSession;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use App\Services\Member\MemberMonthlyWorkoutService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberProfileMonthlyWorkoutCountTest extends TestCase
{
    use DatabaseTransactions;

    private CarbonImmutable $now;

    private MemberProfile $member;

    private MemberProfile $otherMember;

    private TrainerProfile $trainer;

    private int $reservationSequence = 0;

    protected function setUp(): void
    {
        parent::setUp();

        config(['app.timezone' => 'Asia/Jakarta']);
        $this->now = CarbonImmutable::parse('2026-07-15 12:00:00', 'Asia/Jakarta');
        CarbonImmutable::setTestNow($this->now);

        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $this->member = $this->member($memberRole, 'monthly-main');
        $this->otherMember = $this->member($memberRole, 'monthly-other');
        $trainerUser = $this->user($trainerRole, 'monthly-trainer');
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Strength',
        ]);
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_zero_is_an_integer_in_profile_get_and_update_responses(): void
    {
        Sanctum::actingAs($this->member->user, [], 'sanctum');

        $showResponse = $this->getJson('/api/v1/member/profile')
            ->assertOk()
            ->assertJsonPath('data.workouts_this_month', 0);
        $this->assertIsInt($showResponse->json('data.workouts_this_month'));

        $response = $this->putJson('/api/v1/member/profile', [
            'name' => 'Updated Monthly Member',
            'phone' => '081234567890',
        ])->assertOk();

        $this->assertSame(0, $response->json('data.workouts_this_month'));
        $this->assertIsInt($response->json('data.workouts_this_month'));
    }

    public function test_pt_count_uses_completed_sessions_and_actual_completion_month(): void
    {
        $program = $this->trainingProgram($this->member);

        $this->ptSession($program, 'completed', '2026-08-05', '2026-07-20 10:00:00');
        $this->ptSession($program, 'completed', '2026-07-20', '2026-06-30 23:59:59');
        $this->ptSession($program, 'completed', '2026-07-21', null);
        $this->ptSession($program, 'active', '2026-07-22', '2026-07-22 10:00:00');
        $this->unlinkedPtSession($program, 'completed');
        $this->ptSession($this->trainingProgram($this->otherMember), 'completed', '2026-07-23', '2026-07-23 10:00:00');
        $this->ptSession($program, 'completed', '2026-08-01', '2026-07-01 00:00:00');
        $this->ptSession($program, 'completed', '2026-07-31', '2026-08-01 00:00:00');

        $this->assertSame(3, $this->monthlyWorkoutCount());
    }

    public function test_two_completed_pt_sessions_count_twice_not_by_booking_or_program(): void
    {
        $program = $this->trainingProgram($this->member);
        $this->ptSession($program, 'completed', '2026-07-10', '2026-07-10 09:00:00');
        $this->ptSession($program, 'completed', '2026-07-11', '2026-07-11 09:00:00');

        $this->assertSame(2, $this->monthlyWorkoutCount());
    }

    public function test_self_training_counts_each_nonempty_fully_completed_session_once_by_latest_exercise(): void
    {
        $program = SelfTrainingProgram::create([
            'member_profile_id' => $this->member->id,
            'title' => 'Monthly self training',
        ]);

        $current = $this->selfSession($program, 1);
        $this->exercise($current, 1, true, '2026-07-03 08:00:00');
        $this->exercise($current, 2, true, '2026-07-04 08:00:00');

        $incomplete = $this->selfSession($program, 2);
        $this->exercise($incomplete, 1, true, '2026-07-05 08:00:00');
        $this->exercise($incomplete, 2, false, null);

        $this->selfSession($program, 3);

        $previous = $this->selfSession($program, 4);
        $this->exercise($previous, 1, true, '2026-06-30 23:59:59');

        $monthStart = $this->selfSession($program, 5);
        $this->exercise($monthStart, 1, true, '2026-07-01 00:00:00');

        $nextMonth = $this->selfSession($program, 6);
        $this->exercise($nextMonth, 1, true, '2026-08-01 00:00:00');

        $otherProgram = SelfTrainingProgram::create([
            'member_profile_id' => $this->otherMember->id,
            'title' => 'Other member self training',
        ]);
        $other = $this->selfSession($otherProgram, 1);
        $this->exercise($other, 1, true, '2026-07-06 08:00:00');

        $this->assertSame(2, $this->monthlyWorkoutCount());
    }

    private function monthlyWorkoutCount(): int
    {
        return app(MemberMonthlyWorkoutService::class)->countForMember($this->member->id, $this->now);
    }

    private function member(Role $role, string $key): MemberProfile
    {
        $user = $this->user($role, $key);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => strtoupper($key),
            'joined_at' => $this->now,
        ]);
    }

    private function user(Role $role, string $key): User
    {
        return User::create([
            'role_id' => $role->id,
            'name' => $key,
            'email' => $key.'@example.test',
            'phone' => '081234567890',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function trainingProgram(MemberProfile $member): TrainingProgram
    {
        return TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $member->id,
            'title' => 'Monthly PT program '.$member->id,
            'status' => 'active',
        ]);
    }

    private function ptSession(
        TrainingProgram $program,
        string $status,
        string $sessionDate,
        ?string $completedAt,
    ): TrainingProgramSession {
        $session = $this->unlinkedPtSession($program, $status);
        $sequence = ++$this->reservationSequence;
        $scheduleDate = TrainerScheduleDate::firstOrCreate([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => $sessionDate,
        ], [
            'state' => 'open',
            'source' => 'manual',
        ]);
        $booking = Booking::create([
            'member_profile_id' => $program->member_profile_id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Monthly workout',
            'session_date' => $sessionDate,
            'start_time' => '08:00:00',
            'end_time' => '09:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Egg Gym',
            'session_count' => 1,
            'status' => 'confirmed',
        ]);
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => $sequence,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $program->member_profile_id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => $sessionDate,
            'start_time' => '08:00:00',
            'end_time' => '09:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_COMPLETED,
            'completed_at' => $completedAt === null
                ? null
                : CarbonImmutable::parse($completedAt, 'Asia/Jakarta'),
        ]);
        $session->update(['booking_session_reservation_id' => $reservation->id]);

        return $session;
    }

    private function unlinkedPtSession(TrainingProgram $program, string $status): TrainingProgramSession
    {
        return TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'sequence_order' => $program->sessions()->count() + 1,
            'title' => 'PT session',
            'status' => $status,
        ]);
    }

    private function selfSession(SelfTrainingProgram $program, int $sequence): SelfTrainingSession
    {
        return SelfTrainingSession::create([
            'self_training_program_id' => $program->id,
            'sequence_order' => $sequence,
            'title' => 'Self session '.$sequence,
        ]);
    }

    private function exercise(
        SelfTrainingSession $session,
        int $sequence,
        bool $completed,
        ?string $completedAt,
    ): void {
        SelfTrainingExercise::create([
            'self_training_session_id' => $session->id,
            'sequence_order' => $sequence,
            'name' => 'Exercise '.$sequence,
            'sets' => 3,
            'reps' => 10,
            'is_completed' => $completed,
            'completed_at' => $completedAt === null
                ? null
                : CarbonImmutable::parse($completedAt, 'Asia/Jakarta'),
        ]);
    }
}
