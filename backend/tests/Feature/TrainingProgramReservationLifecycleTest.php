<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\TrainerScheduleDate;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use App\Services\Booking\BookingScheduleService;
use App\Services\TrainerAvailabilityService;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainingProgramReservationLifecycleTest extends TestCase
{
    use DatabaseTransactions;

    private TrainerProfile $trainer;

    private User $trainerUser;

    private MemberProfile $member;

    private MemberProfile $otherMember;

    private Booking $booking;

    protected function setUp(): void
    {
        parent::setUp();
        $now = CarbonImmutable::parse('2026-07-21T06:00:00+07:00');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);

        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Lifecycle Trainer',
            'email' => uniqid('lifecycle_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Lifecycle testing',
            'price_per_session' => 100000,
        ]);
        $this->member = $this->createMember('lifecycle', $memberRole);
        $this->otherMember = $this->createMember('other_lifecycle', $memberRole);

        foreach (range(1, 7) as $day) {
            GymOperationHour::updateOrCreate(
                ['day_order' => $day],
                [
                    'day_name' => $now->startOfWeek()->addDays($day - 1)->format('l'),
                    'open_time' => '07:00:00',
                    'close_time' => '22:00:00',
                    'is_closed' => false,
                ]
            );
        }
        foreach (range(21, 25) as $day) {
            $this->setDate("2026-07-{$day}");
        }

        $this->booking = app(BookingScheduleService::class)->create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Lifecycle Series',
            'session_date' => '2026-07-21',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'location' => 'Studio A',
            'session_count' => 3,
            'reservations' => [
                ['session_date' => '2026-07-21', 'start_time' => '08:00:00', 'end_time' => '12:00:00'],
                ['session_date' => '2026-07-22', 'start_time' => '08:00:00', 'end_time' => '12:00:00'],
                ['session_date' => '2026-07-23', 'start_time' => '08:00:00', 'end_time' => '12:00:00'],
            ],
            'status' => 'payment_verified',
        ]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_program_sequence_completion_close_early_and_release_are_consistent(): void
    {
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $programId = $this->postJson('/api/v1/trainer/programs', [
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Lifecycle Program',
            'status' => 'active',
        ])->assertCreated()->json('data.id');

        $sessionIds = [];
        foreach (range(1, 3) as $sequence) {
            $response = $this->postJson("/api/v1/trainer/programs/{$programId}/sessions", [
                'sequence_order' => $sequence,
                'title' => "Session {$sequence}",
            ])->assertCreated();
            $sessionIds[] = $response->json('data.id');
            $this->assertSame(
                $this->booking->sessionReservations[$sequence - 1]->id,
                $response->json('data.booking_session_reservation_id')
            );
        }

        TrainingProgramSession::query()->whereKey($sessionIds[0])->update(['member_ready' => true]);
        $this->postJson("/api/v1/trainer/program-sessions/{$sessionIds[0]}/complete")
            ->assertOk();
        $this->assertDatabaseHas('booking_session_reservations', [
            'id' => $this->booking->sessionReservations[0]->id,
            'status' => 'completed',
        ]);

        $this->postJson("/api/v1/trainer/programs/{$programId}/close-early", [
            'reason' => 'Target member berubah setelah evaluasi.',
        ])->assertOk()
            ->assertJsonPath('data.status', 'closed_early');

        $this->assertDatabaseHas('training_programs', [
            'id' => $programId,
            'status' => 'closed_early',
        ]);
        $this->assertDatabaseHas('training_program_sessions', [
            'id' => $sessionIds[0],
            'status' => 'completed',
        ]);
        $this->assertSame(2, TrainingProgramSession::query()
            ->where('training_program_id', $programId)
            ->where('status', 'cancelled')
            ->count());
        $this->assertDatabaseHas('bookings', [
            'id' => $this->booking->id,
            'status' => 'completed',
        ]);
        $this->assertSame(1, BookingSessionReservation::query()
            ->where('booking_id', $this->booking->id)
            ->where('status', 'completed')
            ->count());
        $this->assertSame(2, BookingSessionReservation::query()
            ->where('booking_id', $this->booking->id)
            ->where('status', 'released')
            ->count());

        $slots = $this->slotsByDate();
        $this->assertTrue($slots['2026-07-22']['is_available']);
        $this->assertTrue($slots['2026-07-23']['is_available']);
    }

    public function test_completed_rated_program_does_not_block_repeat_booking_program(): void
    {
        $oldBooking = Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Completed first engagement',
            'session_date' => '2026-07-24',
            'start_time' => '08:00:00',
            'end_time' => '09:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio A',
            'session_count' => 1,
            'status' => 'completed',
        ]);
        $oldReservation = BookingSessionReservation::create([
            'booking_id' => $oldBooking->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => TrainerScheduleDate::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('schedule_date', '2026-07-24')
                ->value('id'),
            'session_date' => '2026-07-24',
            'start_time' => '08:00:00',
            'end_time' => '09:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_COMPLETED,
            'completed_at' => now(),
        ]);
        $oldProgram = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $oldBooking->id,
            'title' => 'Finished first program',
            // Simulasikan data lama yang parent status-nya belum tersinkronisasi.
            'status' => 'active',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $oldProgram->id,
            'booking_session_reservation_id' => $oldReservation->id,
            'sequence_order' => 1,
            'title' => 'Finished session',
            'status' => 'completed',
        ]);
        TrainerRating::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'booking_id' => $oldBooking->id,
            'training_program_id' => $oldProgram->id,
            'rating' => 5,
        ]);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->getJson('/api/v1/member/dashboard')
            ->assertOk()
            ->assertJsonPath('data.next_session.id', $this->booking->id)
            ->assertJsonPath('data.next_session.session_count', 3)
            ->assertJsonPath('data.next_session.has_program', false)
            ->assertJsonPath('data.next_session.program_completed', false);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->getJson("/api/v1/trainer/sessions/{$this->booking->id}")
            ->assertOk()
            ->assertJsonPath('data.has_program', false)
            ->assertJsonPath('data.training_program_id', null);

        $response = $this->postJson('/api/v1/trainer/programs', [
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Repeat booking program',
            'status' => 'active',
        ])->assertCreated();
        $newProgramId = $response->json('data.id');

        $this->postJson('/api/v1/trainer/programs', [
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Duplicate repeat program',
            'status' => 'active',
        ])->assertStatus(422)
            ->assertJsonPath('message', 'Program untuk booking ini sudah dibuat.');

        foreach (range(1, 3) as $sequence) {
            $this->postJson("/api/v1/trainer/programs/{$newProgramId}/sessions", [
                'sequence_order' => $sequence,
                'title' => "Repeat session {$sequence}",
            ])->assertCreated()
                ->assertJsonPath(
                    'data.booking_session_reservation_id',
                    $this->booking->sessionReservations[$sequence - 1]->id
                );
        }

        $this->assertDatabaseHas('training_programs', [
            'id' => $oldProgram->id,
            'booking_id' => $oldBooking->id,
        ]);
        $this->assertDatabaseHas('training_programs', [
            'id' => $newProgramId,
            'booking_id' => $this->booking->id,
            'status' => 'active',
        ]);
        $this->assertSame(1, TrainingProgram::query()
            ->where('booking_id', $this->booking->id)
            ->count());
        $this->assertSame(3, TrainingProgramSession::query()
            ->where('training_program_id', $newProgramId)
            ->count());
        $this->getJson("/api/v1/trainer/sessions/{$this->booking->id}")
            ->assertOk()
            ->assertJsonPath('data.has_program', true)
            ->assertJsonPath('data.training_program_id', $newProgramId);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $programs = $this->getJson('/api/v1/member/programs')->assertOk();
        $this->assertSame('completed', collect($programs->json('data'))
            ->firstWhere('id', $oldProgram->id)['status']);
        $this->assertSame('active', collect($programs->json('data'))
            ->firstWhere('id', $newProgramId)['status']);
    }

    public function test_direct_occurrence_reschedule_requires_approval_and_enforces_ownership(): void
    {
        $reservation = $this->booking->sessionReservations[1];
        $otherTrainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $otherTrainerUser = User::create([
            'role_id' => $otherTrainerRole->id,
            'name' => 'Other Lifecycle Trainer',
            'email' => uniqid('other_lifecycle_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        TrainerProfile::create([
            'user_id' => $otherTrainerUser->id,
            'specialty' => 'Ownership testing',
            'price_per_session' => 100000,
        ]);
        $payload = [
            'new_session_date' => '2026-07-25',
            'new_start_time' => '08:00:00',
            'new_end_time' => '12:00:00',
            'reason' => 'Memindahkan satu occurrence.',
        ];

        Sanctum::actingAs($otherTrainerUser, [], 'sanctum');
        $this->postJson(
            "/api/v1/trainer/sessions/{$this->booking->id}/reservations/{$reservation->id}/reschedule",
            $payload
        )->assertNotFound();

        Sanctum::actingAs($this->otherMember->user, [], 'sanctum');
        $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule",
            $payload
        )->assertNotFound();

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson(
            "/api/v1/trainer/sessions/{$this->booking->id}/reservations/{$reservation->id}/reschedule",
            $payload
        )->assertStatus(422)
            ->assertJsonPath('message', 'Booking baru wajib menggunakan approval reschedule request.');

        $this->assertDatabaseHas('booking_session_reservations', [
            'id' => $reservation->id,
            'session_date' => '2026-07-22',
            'status' => 'reserved',
        ]);
        $this->assertDatabaseHas('booking_session_reservations', [
            'booking_id' => $this->booking->id,
            'sequence_order' => 1,
            'session_date' => '2026-07-21',
        ]);
        $this->assertDatabaseHas('booking_session_reservations', [
            'booking_id' => $this->booking->id,
            'sequence_order' => 3,
            'session_date' => '2026-07-23',
        ]);

        $slots = $this->slotsByDate();
        $this->assertFalse($slots['2026-07-22']['is_available']);
        $this->assertTrue($slots['2026-07-25']['is_available']);

        app(BookingScheduleService::class)->cancelBookingReservations($this->booking);
        $this->assertSame(3, BookingSessionReservation::query()
            ->where('booking_id', $this->booking->id)
            ->where('status', 'cancelled')
            ->count());
    }

    public function test_final_session_completion_persists_parent_program_status(): void
    {
        $booking = Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Single completion lifecycle',
            'session_date' => '2026-07-21',
            'start_time' => '13:00:00',
            'end_time' => '14:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio A',
            'session_count' => 1,
            'status' => 'payment_verified',
        ]);
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => TrainerScheduleDate::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('schedule_date', '2026-07-21')
                ->value('id'),
            'session_date' => '2026-07-21',
            'start_time' => '13:00:00',
            'end_time' => '14:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $booking->id,
            'title' => 'Single completion program',
            'status' => 'active',
        ]);
        $session = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservation->id,
            'sequence_order' => 1,
            'title' => 'Only session',
            'status' => 'active',
            'member_ready' => true,
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/program-sessions/{$session->id}/complete")
            ->assertOk();

        $this->assertDatabaseHas('training_programs', [
            'id' => $program->id,
            'status' => 'completed',
        ]);
        $this->assertNotNull($program->fresh()->ended_at);
        $this->assertDatabaseHas('bookings', [
            'id' => $booking->id,
            'status' => 'completed',
        ]);
        $this->assertDatabaseHas('booking_session_reservations', [
            'id' => $reservation->id,
            'status' => BookingSessionReservation::STATUS_COMPLETED,
        ]);
    }

    private function slotsByDate(): \Illuminate\Support\Collection
    {
        $availability = app(TrainerAvailabilityService::class)->availability($this->trainer);

        return collect($availability['weekdays'])
            ->flatMap(fn (array $weekday) => $weekday['occurrences'])
            ->keyBy('date')
            ->map(fn (array $occurrence) => collect($occurrence['slots'])->first());
    }

    private function createMember(string $prefix, Role $role): MemberProfile
    {
        $user = User::create([
            'role_id' => $role->id,
            'name' => ucfirst($prefix).' Member',
            'email' => uniqid("{$prefix}_", true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid(strtoupper($prefix).'-'),
        ]);
    }

    private function setDate(string $date): void
    {
        $parent = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => $date,
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $parent->shifts()->create([
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
        ]);
    }
}
