<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\Booking\BookingRequestExpiryService;
use App\Services\Booking\BookingScheduleService;
use App\Services\TrainerAvailabilityService;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BookingExpiryLifecycleTest extends TestCase
{
    use DatabaseTransactions;

    private CarbonImmutable $now;

    private User $trainerUser;

    private TrainerProfile $trainer;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();
        $this->now = CarbonImmutable::parse('2026-07-21T08:00:00+07:00');
        Carbon::setTestNow($this->now);
        CarbonImmutable::setTestNow($this->now);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Expiry Trainer',
            'email' => uniqid('expiry_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Expiry testing',
            'price_per_session' => 100000,
        ]);
        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Expiry Member',
            'email' => uniqid('expiry_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('EXP-'),
            'height_cm' => 170,
            'weight_kg' => 70,
            'fitness_goal' => 'Expiry testing',
        ]);
        foreach (range(1, 7) as $day) {
            GymOperationHour::updateOrCreate(['day_order' => $day], [
                'day_name' => $this->now->startOfWeek()->addDays($day - 1)->format('l'),
                'open_time' => '07:00:00',
                'close_time' => '22:00:00',
                'is_closed' => false,
            ]);
        }
        $date = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-23',
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $date->shifts()->create([
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
        ]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_full_deadline_transitions_and_rejected_proof_reset(): void
    {
        $booking = $this->createBooking();
        $this->trainer->update([
            'display_photo_path' => 'trainer-display-photos/elena.jpg',
        ]);
        $this->trainerUser->update([
            'avatar_url' => 'avatars/elena.jpg',
        ]);
        $this->assertSame('2026-07-21T09:00:00+07:00', $booking->expired_at->toIso8601String());

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/confirm")
            ->assertOk()
            ->assertJsonPath('data.status', 'waiting_payment')
            ->assertJsonPath('data.expiry_stage', 'member_payment');
        $booking->refresh();
        $this->assertSame('2026-07-21T09:00:00+07:00', $booking->expired_at->toIso8601String());

        Storage::fake('public');
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/bookings/{$booking->id}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('proof.jpg'),
        ])->assertOk()
            ->assertJsonPath('data.status', 'payment_uploaded')
            ->assertJsonPath('data.expiry_stage', 'trainer_verification');
        $booking->refresh();
        $this->assertSame('2026-07-21T09:00:00+07:00', $booking->expired_at->toIso8601String());

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/verify-payment", [
            'verified' => false,
            'rejection_note' => 'Bukti tidak terbaca.',
        ])->assertOk()
            ->assertJsonPath('data.status', 'payment_rejected')
            ->assertJsonPath('data.expiry_stage', 'member_payment');
        $booking->refresh();
        $this->assertSame('2026-07-21T09:00:00+07:00', $booking->expired_at->toIso8601String());
        $this->assertTrue(Booking::blocksSchedule($booking->status));

        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->getJson('/api/v1/member/dashboard')
            ->assertOk()
            ->assertJsonPath('data.next_session.id', $booking->id)
            ->assertJsonPath('data.next_session.status', 'payment_rejected')
            ->assertJsonPath('data.next_session.trainer_display_photo_path', 'trainer-display-photos/elena.jpg')
            ->assertJsonPath('data.next_session.trainer_avatar_url', 'avatars/elena.jpg');

        $this->postJson("/api/v1/member/bookings/{$booking->id}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('proof-again.jpg'),
        ])->assertOk()->assertJsonPath('data.status', 'payment_uploaded');

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/verify-payment", [
            'verified' => true,
        ])->assertOk()->assertJsonPath('data.status', 'payment_verified');
        $this->assertNull($booking->refresh()->expired_at);
        $this->assertDatabaseHas('booking_session_reservations', [
            'booking_id' => $booking->id,
            'status' => 'reserved',
        ]);
    }

    public function test_overdue_booking_expires_releases_reserved_only_and_is_idempotent(): void
    {
        $booking = $this->createBooking();
        $reservation = $booking->sessionReservations->first();
        $extra = $booking->sessionReservations()->create([
            'sequence_order' => 2,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $reservation->trainer_schedule_date_id,
            'session_date' => '2026-07-23',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
            'status' => 'completed',
            'completed_at' => now(),
        ]);
        Carbon::setTestNow($this->now->addHour()->addSecond());
        CarbonImmutable::setTestNow($this->now->addHour()->addSecond());

        $service = app(BookingRequestExpiryService::class);
        $expired = $service->ensureNotExpired($booking);
        $this->assertSame('expired', $expired->status);
        $this->assertDatabaseHas('booking_session_reservations', [
            'id' => $reservation->id,
            'status' => 'released',
        ]);
        $this->assertDatabaseHas('booking_session_reservations', [
            'id' => $extra->id,
            'status' => 'completed',
        ]);
        $this->assertSame(0, $service->expirePendingBookings());

        $availability = app(TrainerAvailabilityService::class)->availability($this->trainer);
        $slot = collect($availability['weekdays'])
            ->flatMap(fn (array $weekday) => $weekday['occurrences'])
            ->firstWhere('date', '2026-07-23')['slots'][0];
        $this->assertTrue($slot['is_available']);
    }

    public function test_action_after_deadline_is_rejected_and_legacy_null_is_untouched(): void
    {
        $booking = $this->createBooking();
        Carbon::setTestNow($this->now->addHour()->addSecond());
        CarbonImmutable::setTestNow($this->now->addHour()->addSecond());
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/confirm")
            ->assertStatus(422);
        $this->assertSame('expired', $booking->refresh()->status);

        $legacy = Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Legacy no expiry',
            'session_date' => '2026-07-23',
            'start_time' => '13:00:00',
            'end_time' => '14:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio A',
            'status' => 'pending',
        ]);
        app(BookingRequestExpiryService::class)->expirePendingBookings();
        $this->assertSame('pending', $legacy->refresh()->status);
        $this->assertNull($legacy->expired_at);
    }

    public function test_member_payment_phases_expire_with_correct_stage(): void
    {
        $cases = [
            ['status' => 'waiting_payment', 'hours' => 1, 'stage' => 'member_payment'],
            ['status' => 'payment_rejected', 'hours' => 1, 'stage' => 'member_payment'],
        ];
        $service = app(BookingRequestExpiryService::class);

        foreach ($cases as $case) {
            Carbon::setTestNow($this->now);
            CarbonImmutable::setTestNow($this->now);
            $booking = $this->createBooking();
            $booking->update([
                'status' => $case['status'],
                'expired_at' => $service->resolveBookingExpiryTimestamp(
                    $booking,
                    $case['status']
                ),
                'trainer_note' => 'Catatan trainer tetap dipertahankan.',
            ]);
            Carbon::setTestNow($this->now->addHours($case['hours'])->addSecond());
            CarbonImmutable::setTestNow($this->now->addHours($case['hours'])->addSecond());

            $expired = $service->ensureNotExpired($booking);
            $this->assertSame('expired', $expired->status);
            $this->assertSame($case['stage'], $service->expiryStage($expired));
            $this->assertStringContainsString(
                'Catatan trainer tetap dipertahankan.',
                (string) $expired->trainer_note
            );
            $this->assertSame(1, $expired->sessionReservations
                ->where('status', 'released')
                ->count());
        }
    }

    public function test_uploaded_proof_becomes_overdue_without_expiring_or_releasing_and_reminder_is_idempotent(): void
    {
        Storage::fake('public');
        $booking = $this->createBooking();
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/confirm")->assertOk();
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/bookings/{$booking->id}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('overdue-proof.jpg'),
        ])->assertOk();
        $booking->refresh();
        $reservation = $booking->sessionReservations->first();
        $proofPath = $booking->payment_proof_path;
        $this->assertNotNull($booking->payment_proof_uploaded_at);

        Carbon::setTestNow($this->now->addHour()->addSecond());
        CarbonImmutable::setTestNow($this->now->addHour()->addSecond());
        $service = app(BookingRequestExpiryService::class);

        $this->assertSame(0, $service->expirePendingBookings());
        $booking->refresh();
        $this->assertSame('payment_uploaded', $booking->status);
        $this->assertTrue($service->isPaymentVerificationOverdue($booking));
        $this->assertSame(1, $service->verificationOverdueSeconds($booking));
        $this->assertSame('reserved', $reservation->fresh()->status);
        $this->assertSame($proofPath, $booking->payment_proof_path);
        Storage::disk('public')->assertExists($proofPath);
        $this->assertNotNull($booking->verification_overdue_notified_at);
        $this->assertSame(1, UserNotification::query()
            ->where('user_id', $this->trainerUser->id)
            ->where('title', 'Verifikasi Pembayaran Terlambat')
            ->count());

        $this->assertSame(0, $service->expirePendingBookings());
        $this->assertSame(1, UserNotification::query()
            ->where('user_id', $this->trainerUser->id)
            ->where('title', 'Verifikasi Pembayaran Terlambat')
            ->count());

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/verify-payment", [
            'verified' => true,
        ])->assertOk()
            ->assertJsonPath('data.status', 'payment_verified')
            ->assertJsonPath('data.is_payment_verification_overdue', false);
        $this->assertSame('reserved', $reservation->fresh()->status);
    }

    public function test_trainer_can_reject_overdue_proof_and_member_receives_new_hard_upload_deadline(): void
    {
        Storage::fake('public');
        $booking = $this->createBooking();
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/confirm")->assertOk();
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/bookings/{$booking->id}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('rejected-overdue.jpg'),
        ])->assertOk();

        Carbon::setTestNow($this->now->addHour()->addSecond());
        CarbonImmutable::setTestNow($this->now->addHour()->addSecond());
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/verify-payment", [
            'verified' => false,
            'rejection_note' => 'Nominal belum cocok.',
        ])->assertOk()
            ->assertJsonPath('data.status', 'payment_rejected')
            ->assertJsonPath('data.expiry_stage', 'member_payment')
            ->assertJsonPath('data.is_payment_verification_overdue', false);

        $booking->refresh();
        $this->assertSame('payment_rejected', $booking->status);
        $this->assertTrue($booking->expired_at->isFuture());
        $this->assertSame('reserved', $booking->sessionReservations->first()->status);
    }

    public function test_deadline_is_capped_at_first_session_start_for_t_minus_two_booking(): void
    {
        $date = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-21',
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $date->shifts()->create([
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
        ]);
        $booking = app(BookingScheduleService::class)->create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'T minus two booking',
            'location' => 'Studio A',
            'session_count' => 1,
            'reservations' => [[
                'session_date' => '2026-07-21',
                'start_time' => '10:00:00',
                'end_time' => '11:00:00',
            ]],
            'status' => 'pending',
        ]);
        $this->assertSame('2026-07-21T09:00:00+07:00', $booking->expired_at->toIso8601String());

        Carbon::setTestNow($this->now->addMinutes(30));
        CarbonImmutable::setTestNow($this->now->addMinutes(30));
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/confirm")
            ->assertOk();
        $this->assertSame(
            '2026-07-21T09:30:00+07:00',
            $booking->refresh()->expired_at->toIso8601String()
        );

        Carbon::setTestNow($this->now->addHour()->addMinutes(20));
        CarbonImmutable::setTestNow($this->now->addHour()->addMinutes(20));
        Storage::fake('public');
        Sanctum::actingAs($this->member->user, [], 'sanctum');
        $this->postJson("/api/v1/member/bookings/{$booking->id}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('capped-proof.jpg'),
        ])->assertOk();
        $this->assertSame(
            '2026-07-21T10:00:00+07:00',
            $booking->refresh()->expired_at->toIso8601String()
        );

        Carbon::setTestNow($this->now->addHour()->addMinutes(40));
        CarbonImmutable::setTestNow($this->now->addHour()->addMinutes(40));
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson("/api/v1/trainer/sessions/{$booking->id}/verify-payment", [
            'verified' => false,
            'rejection_note' => 'Mohon upload ulang.',
        ])->assertOk();
        $this->assertSame(
            '2026-07-21T10:00:00+07:00',
            $booking->refresh()->expired_at->toIso8601String()
        );
    }

    private function createBooking(): Booking
    {
        return app(BookingScheduleService::class)->create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Expiry Booking',
            'location' => 'Studio A',
            'session_count' => 1,
            'reservations' => [[
                'session_date' => '2026-07-23',
                'start_time' => '08:00:00',
                'end_time' => '12:00:00',
            ]],
            'status' => 'pending',
        ]);
    }
}
