<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingRescheduleRequest;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\TrainingProgramSessionExercise;
use App\Models\User;
use App\Services\Booking\BookingScheduleService;
use App\Services\TrainerAvailabilityService;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BookingRescheduleApprovalTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainerProfile $trainer;

    private MemberProfile $member;

    private Booking $booking;

    protected function setUp(): void
    {
        parent::setUp();
        $now = CarbonImmutable::parse('2026-07-22T08:00:00+07:00');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id, 'name' => 'Approval Trainer',
            'email' => uniqid('approval_trainer_', true).'@test.local',
            'password' => 'password', 'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Approval', 'price_per_session' => 100000,
        ]);
        $memberUser = User::create([
            'role_id' => $memberRole->id, 'name' => 'Approval Member',
            'email' => uniqid('approval_member_', true).'@test.local',
            'password' => 'password', 'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id, 'member_code' => uniqid('APR-'),
            'height_cm' => 170, 'weight_kg' => 70, 'fitness_goal' => 'Fit',
        ]);
        foreach (range(1, 7) as $day) {
            GymOperationHour::updateOrCreate(['day_order' => $day], [
                'day_name' => $now->startOfWeek()->addDays($day - 1)->format('l'),
                'open_time' => '07:00:00', 'close_time' => '22:00:00', 'is_closed' => false,
            ]);
        }
        foreach (['2026-07-23', '2026-07-24', '2026-07-25', '2026-07-26'] as $date) {
            $parent = TrainerScheduleDate::create([
                'trainer_profile_id' => $this->trainer->id, 'schedule_date' => $date,
                'state' => 'open', 'source' => 'manual', 'overridden_at' => now(),
            ]);
            $parent->shifts()->create([
                'start_time' => '08:00:00', 'end_time' => '12:00:00',
                'session_duration_minutes' => 240,
            ]);
        }
        $this->booking = app(BookingScheduleService::class)->create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Approval Booking', 'location' => 'Studio A',
            'session_count' => 1, 'status' => 'payment_verified',
            'reservations' => [[
                'session_date' => '2026-07-24',
                'start_time' => '08:00:00', 'end_time' => '12:00:00',
            ]],
        ]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_member_request_holds_target_and_trainer_accept_moves_only_on_accept(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Program Identity',
            'status' => 'active',
        ]);
        $programSession = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservation->id,
            'sequence_order' => 1,
            'title' => 'Isi Latihan Sesi 1',
            'status' => 'active',
        ]);
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $response = $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests",
            $this->proposal('2026-07-25')
        )->assertCreated()->assertJsonPath('data.status', 'pending');
        $requestId = $response->json('data.id');
        $this->assertSame('2026-07-24', $reservation->refresh()->session_date->toDateString());
        $this->assertSame(1, BookingRescheduleRequest::query()
            ->where('booking_id', $this->booking->id)
            ->where('status', 'pending')
            ->count());
        $this->assertFalse($this->slotAvailable('2026-07-25'));

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/reschedule-requests/{$requestId}/accept")
            ->assertForbidden();

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/reschedule-requests/{$requestId}/accept")
            ->assertOk()->assertJsonPath('data.status', 'accepted');
        $this->assertSame('2026-07-25', $reservation->refresh()->session_date->toDateString());
        $this->assertTrue($this->slotAvailable('2026-07-24'));
        $this->assertFalse($this->slotAvailable('2026-07-25'));
        $this->assertSame(100000.0, (float) $this->booking->refresh()->total_amount_snapshot);
        $this->assertSame(1, $this->booking->session_count);
        $this->assertSame($reservation->id, $programSession->refresh()->booking_session_reservation_id);
        $this->assertSame(1, $programSession->sequence_order);
        $this->assertSame('Isi Latihan Sesi 1', $programSession->title);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->getJson("/api/v1/member/programs/{$program->id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.id', $programSession->id)
            ->assertJsonPath('data.sessions.0.sequence_order', 1)
            ->assertJsonPath('data.sessions.0.booking_session_reservation_id', $reservation->id)
            ->assertJsonPath('data.sessions.0.reservation.session_date', '2026-07-25')
            ->assertJsonPath('data.sessions.0.reservation.start_time', '08:00:00');
    }

    public function test_reject_cancel_and_expire_keep_old_schedule_and_release_hold(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $requestId = $this->postJson(
            "/api/v1/trainer/sessions/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests",
            $this->proposal('2026-07-25', 'urgent_schedule')
        )->assertCreated()->json('data.id');
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/reschedule-requests/{$requestId}/reject", [
            'rejected_reason_type' => 'new_schedule_not_suitable',
            'rejected_reason_note' => 'Tidak bisa hadir.',
        ])->assertOk()->assertJsonPath('data.status', 'rejected');
        $this->assertSame('2026-07-24', $reservation->refresh()->session_date->toDateString());
        $this->assertTrue($this->slotAvailable('2026-07-25'));

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $cancelId = $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests",
            $this->proposal('2026-07-25')
        )->assertCreated()->json('data.id');
        $this->postJson("/api/v1/member/reschedule-requests/{$cancelId}/cancel")
            ->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertTrue($this->slotAvailable('2026-07-25'));

        $expireId = $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests",
            $this->proposal('2026-07-25')
        )->assertCreated()->json('data.id');
        BookingRescheduleRequest::whereKey($expireId)->update(['expired_at' => now()->subSecond()]);
        $this->getJson('/api/v1/member/reschedule-requests')->assertOk();
        $this->assertDatabaseHas('booking_reschedule_requests', ['id' => $expireId, 'status' => 'expired']);
        $this->assertTrue($this->slotAvailable('2026-07-25'));
        $this->assertSame('2026-07-24', $reservation->refresh()->session_date->toDateString());
    }

    public function test_duplicate_pending_same_slot_and_invalid_status_are_rejected(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $url = "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests";
        $this->postJson($url, $this->proposal('2026-07-25'))->assertCreated();
        $this->postJson($url, $this->proposal('2026-07-26'))->assertConflict();

        $this->booking->update(['status' => 'waiting_payment']);
        $other = $this->booking->sessionReservations->first();
        BookingRescheduleRequest::query()->update(['status' => 'cancelled', 'active_reservation_id' => null]);
        $this->postJson($url, $this->proposal('2026-07-26'))->assertStatus(422);
        $this->assertSame('2026-07-24', $other->refresh()->session_date->toDateString());
    }

    public function test_request_cannot_move_backward_or_reuse_sibling_reservation_date(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        $this->booking->sessionReservations()->create([
            'sequence_order' => 2,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => TrainerScheduleDate::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('schedule_date', '2026-07-26')
                ->value('id'),
            'session_date' => '2026-07-26',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
            'status' => 'reserved',
        ]);
        $this->booking->update(['session_count' => 2, 'total_amount_snapshot' => 200000]);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $url = "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests";

        $this->postJson($url, $this->proposal('2026-07-23'))
            ->assertStatus(422)
            ->assertJsonPath('message', 'Jadwal baru harus lebih maju dari jadwal sesi saat ini.');
        $this->postJson($url, $this->proposal('2026-07-26'))
            ->assertStatus(422)
            ->assertJsonPath('message', 'Tanggal tersebut sudah dipakai sesi lain dalam booking ini.');

        $this->assertSame(0, BookingRescheduleRequest::query()
            ->where('booking_id', $this->booking->id)
            ->count());
        $this->assertSame('2026-07-24', $reservation->refresh()->session_date->toDateString());
    }

    public function test_reschedule_availability_is_scoped_to_booking_owner(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->getJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-availability"
        )->assertOk()
            ->assertJsonPath('data.trainer_profile_id', $this->trainer->id)
            ->assertJsonPath('data.slot_policy', 'shift_interval');

        $otherMemberRole = Role::firstOrCreate(['name' => 'member']);
        $otherUser = User::create([
            'role_id' => $otherMemberRole->id,
            'name' => 'Other Availability Member',
            'email' => uniqid('other_availability_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        MemberProfile::create([
            'user_id' => $otherUser->id,
            'member_code' => uniqid('OTHER-AVAILABILITY-'),
        ]);
        Sanctum::actingAs($otherUser, [], 'sanctum');
        $this->getJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-availability"
        )->assertNotFound();
    }

    public function test_pending_request_blocks_only_linked_program_session_execution(): void
    {
        $reservation = $this->booking->sessionReservations->first();
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Pending Guard Program',
            'status' => 'active',
        ]);
        $programSession = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservation->id,
            'sequence_order' => 1,
            'title' => 'Protected Session',
            'status' => 'active',
            'member_ready' => true,
        ]);
        $exercise = TrainingProgramSessionExercise::create([
            'training_program_session_id' => $programSession->id,
            'sequence_order' => 1,
            'custom_name' => 'Protected Exercise',
            'sets' => 3,
            'reps' => 10,
            'status' => 'active',
        ]);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $requestId = $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservation->id}/reschedule-requests",
            $this->proposal('2026-07-25')
        )->assertCreated()->json('data.id');

        $this->getJson("/api/v1/member/programs/{$program->id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.reservation.has_pending_reschedule', true);
        $this->postJson("/api/v1/member/programs/{$program->id}/sessions/{$programSession->id}/ready")
            ->assertConflict()
            ->assertJsonPath('message', 'Sesi tidak dapat dimulai atau diperbarui selama permintaan reschedule masih menunggu keputusan.');
        $this->assertTrue($programSession->refresh()->member_ready);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->getJson("/api/v1/trainer/programs/{$program->id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.reservation.has_pending_reschedule', true);
        $this->postJson("/api/v1/trainer/program-sessions/{$programSession->id}/progress", [
            'exercise_id' => $exercise->id,
            'completed_sets' => 1,
        ])->assertConflict();
        $this->postJson("/api/v1/trainer/program-sessions/{$programSession->id}/complete")
            ->assertConflict();
        $this->assertDatabaseMissing('trainer_session_progresses', [
            'training_program_session_id' => $programSession->id,
        ]);
        $this->assertSame('active', $programSession->refresh()->status);
        $this->assertSame('reserved', $reservation->refresh()->status);

        $this->postJson("/api/v1/trainer/reschedule-requests/{$requestId}/accept")
            ->assertOk();
        $this->getJson("/api/v1/trainer/programs/{$program->id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.reservation.has_pending_reschedule', false);
    }

    public function test_accept_reconciles_active_session_by_reservation_datetime_and_completion_advances_chronologically(): void
    {
        $reservationOne = $this->booking->sessionReservations->first();
        $reservationTwo = $this->booking->sessionReservations()->create([
            'sequence_order' => 2,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => TrainerScheduleDate::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('schedule_date', '2026-07-25')
                ->value('id'),
            'session_date' => '2026-07-25',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
            'status' => 'reserved',
        ]);
        $this->booking->update(['session_count' => 2, 'total_amount_snapshot' => 200000]);
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Chronological Program',
            'status' => 'active',
        ]);
        $sessionOne = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservationOne->id,
            'sequence_order' => 1,
            'title' => 'Isi Latihan Sesi 1',
            'status' => 'active',
        ]);
        $sessionTwo = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservationTwo->id,
            'sequence_order' => 2,
            'title' => 'Isi Latihan Sesi 2',
            'status' => 'locked',
        ]);
        TrainingProgramSessionExercise::create([
            'training_program_session_id' => $sessionTwo->id,
            'sequence_order' => 1,
            'custom_name' => 'Latihan Tetap Sesi 2',
            'sets' => 3,
            'reps' => 10,
            'status' => 'active',
        ]);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $requestId = $this->postJson(
            "/api/v1/member/bookings/{$this->booking->id}/reservations/{$reservationOne->id}/reschedule-requests",
            $this->proposal('2026-07-26')
        )->assertCreated()->json('data.id');
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/reschedule-requests/{$requestId}/accept")
            ->assertOk();

        $this->assertSame('locked', $sessionOne->refresh()->status);
        $this->assertSame('active', $sessionTwo->refresh()->status);
        $this->assertSame(1, $sessionOne->sequence_order);
        $this->assertSame($reservationOne->id, $sessionOne->booking_session_reservation_id);
        $this->assertSame('Isi Latihan Sesi 1', $sessionOne->title);
        $this->assertSame(2, $sessionTwo->sequence_order);
        $this->assertSame($reservationTwo->id, $sessionTwo->booking_session_reservation_id);
        $this->assertSame('Isi Latihan Sesi 2', $sessionTwo->title);

        $sessionTwo->update(['member_ready' => true]);
        $this->postJson("/api/v1/trainer/program-sessions/{$sessionTwo->id}/complete")
            ->assertOk();
        $this->assertSame('completed', $sessionTwo->refresh()->status);
        $this->assertSame('completed', $reservationTwo->refresh()->status);
        $this->assertSame('active', $sessionOne->refresh()->status);
        $this->assertSame('reserved', $reservationOne->refresh()->status);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $detail = $this->getJson("/api/v1/member/programs/{$program->id}")->assertOk();
        $sessions = collect($detail->json('data.sessions'))->keyBy('sequence_order');
        $this->assertSame('active', $sessions[1]['status']);
        $this->assertSame('completed', $sessions[2]['status']);
        $this->assertSame('2026-07-26', $sessions[1]['reservation']['session_date']);
        $this->assertSame('2026-07-25', $sessions[2]['reservation']['session_date']);
    }

    public function test_program_detail_lazily_repairs_stale_status_from_preexisting_accepted_reschedule(): void
    {
        $reservationOne = $this->booking->sessionReservations->first();
        $reservationOne->update(['session_date' => '2026-07-27']);
        $reservationTwo = $this->booking->sessionReservations()->create([
            'sequence_order' => 2,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => TrainerScheduleDate::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('schedule_date', '2026-07-25')
                ->value('id'),
            'session_date' => '2026-07-25',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
            'status' => 'reserved',
        ]);
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $this->booking->id,
            'title' => 'Stale Existing Program',
            'status' => 'active',
        ]);
        $sessionOne = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservationOne->id,
            'sequence_order' => 1,
            'title' => 'Sesi 1 Existing',
            'status' => 'active',
        ]);
        $sessionTwo = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservationTwo->id,
            'sequence_order' => 2,
            'title' => 'Sesi 2 Existing',
            'status' => 'locked',
        ]);

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $detail = $this->getJson("/api/v1/member/programs/{$program->id}")->assertOk();
        $memberSessions = collect($detail->json('data.sessions'))->keyBy('sequence_order');
        $this->assertSame('locked', $memberSessions[1]['status']);
        $this->assertSame('active', $memberSessions[2]['status']);
        $this->assertSame('locked', $sessionOne->refresh()->status);
        $this->assertSame('active', $sessionTwo->refresh()->status);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $trainerDetail = $this->getJson("/api/v1/trainer/programs/{$program->id}")->assertOk();
        $trainerSessions = collect($trainerDetail->json('data.sessions'))->keyBy('sequence_order');
        $this->assertSame('locked', $trainerSessions[1]['status']);
        $this->assertSame('active', $trainerSessions[2]['status']);
    }

    private function proposal(string $date, string $reason = 'schedule_conflict'): array
    {
        return [
            'proposed_session_date' => $date,
            'proposed_start_time' => '08:00:00',
            'proposed_end_time' => '12:00:00',
            'reason_type' => $reason,
            'reason_note' => 'Perlu menyesuaikan jadwal.',
        ];
    }

    private function slotAvailable(string $date): bool
    {
        $data = app(TrainerAvailabilityService::class)->availability($this->trainer);
        $occurrence = collect($data['weekdays'])->flatMap(fn ($day) => $day['occurrences'])
            ->firstWhere('date', $date);

        return (bool) ($occurrence['slots'][0]['is_available'] ?? false);
    }
}
