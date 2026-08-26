<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\TrainerSessionProgress;
use App\Models\TrainerSessionProgressExercise;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\TrainingProgramSessionExercise;
use App\Models\User;
use App\Services\Booking\BookingRequestExpiryService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminBookingMonitoringTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private MemberProfile $member;

    private TrainerProfile $trainer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->createUser('admin', 'Booking Monitor Admin');
        $memberUser = $this->createUser('member', 'Live Monitor Member', 'avatars/live-member.jpg');
        $trainerUser = $this->createUser('trainer', 'Live Monitor Trainer');
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => 'MON-'.uniqid(),
            'joined_at' => '2026-07-01',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'tier' => 'pro',
            'max_clients' => 30,
            'rating' => 4.5,
        ]);
    }

    public function test_tabs_counts_search_and_schedule_use_real_booking_data(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-07-24 10:30:00', 'Asia/Jakarta'));

        $pending = $this->createBooking('pending', '2026-07-25', '08:00:00', '09:00:00');
        $confirmed = $this->createBooking('payment_rejected', '2026-07-25', '09:00:00', '10:00:00');
        $completed = $this->createBooking('completed', '2026-07-25', '10:00:00', '11:00:00');
        $expired = $this->createBooking('expired', '2026-07-25', '11:00:00', '12:00:00');
        foreach (range(1, 5) as $index) {
            $this->createBooking('pending', '2026-08-'.str_pad((string) $index, 2, '0', STR_PAD_LEFT), '08:00:00', '09:00:00');
        }

        BookingSessionReservation::create([
            'booking_id' => $pending->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $this->scheduleDate('2026-07-28')->id,
            'session_date' => '2026-07-28',
            'start_time' => '14:00:00',
            'end_time' => '15:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);
        BookingSessionReservation::create([
            'booking_id' => $pending->id,
            'sequence_order' => 2,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $this->scheduleDate('2026-07-30')->id,
            'session_date' => '2026-07-30',
            'start_time' => '16:00:00',
            'end_time' => '17:00:00',
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);

        $response = $this->adminGet(route('admin.bookings.index', ['status' => 'menunggu']));
        $response->assertOk()
            ->assertViewHas('bookings', fn ($bookings) => $bookings->perPage() === 5
                && $bookings->count() === 5
                && $bookings->total() >= 6
                && $bookings->currentPage() === 1)
            ->assertViewHas('counts', fn (array $counts) => $counts['menunggu'] >= 1
                && $counts['dikonfirmasi'] >= 1
                && $counts['selesai'] >= 1
                && $counts['ditolak'] >= 1)
            ->assertSeeText('Live Monitor Member')
            ->assertSeeText('Live Monitor Trainer')
            ->assertSeeText('28 Juli 2026')
            ->assertSeeText('14:00 - 15:00')
            ->assertSeeText('2 sesi terjadwal')
            ->assertSeeText('Menunggu Konfirmasi')
            ->assertDontSeeText('Coach Incentive Active')
            ->assertDontSeeText('Tier 2 Bonuses')
            ->assertDontSee('data-can-reject=', false)
            ->assertDontSee('data-reject-url=', false)
            ->assertDontSee("bkActionForm(d.rejectUrl, 'Tolak'", false)
            ->assertSee('Menampilkan 1&ndash;5 dari', false)
            ->assertSeeText('booking')
            ->assertSee('class="adm-pager__nav is-disabled">Prev</span>', false)
            ->assertSee('rel="next">Next</a>', false)
            ->assertSee("document.querySelectorAll('.bk-panel .adm-pager a')", false);

        $this->adminGet(route('admin.bookings.index', [
            'status' => 'menunggu',
            'search' => 'Live Monitor Member',
            'page' => 2,
        ]))->assertOk()
            ->assertViewHas('bookings', fn ($bookings) => $bookings->perPage() === 5
                && $bookings->currentPage() === 2
                && $bookings->count() >= 1)
            ->assertSee('status=menunggu', false)
            ->assertSee('search=Live%20Monitor%20Member', false);

        $this->adminGet(route('admin.bookings.index', [
            'status' => 'menunggu',
            'search' => '2026-07-30',
        ]))->assertOk()->assertSeeText('Live Monitor Member');

        $this->adminGet(route('admin.bookings.index', [
            'status' => 'dikonfirmasi',
            'search' => 'Live Monitor Trainer',
        ]))->assertOk()->assertSeeText('Pembayaran Ditolak');

        $this->adminGet(route('admin.bookings.index', ['status' => 'selesai']))
            ->assertOk()->assertSeeText('Selesai');
        $this->adminGet(route('admin.bookings.index', [
            'status' => 'ditolak',
            'search' => '#'.$expired->id,
        ]))
            ->assertOk()->assertSeeText('Kedaluwarsa');

        $this->assertNotNull($confirmed->id);
        $this->assertNotNull($completed->id);
        $this->assertNotNull($expired->id);
    }

    public function test_live_progress_uses_persisted_sets_for_paid_active_session_today(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-07-24 10:30:00', 'Asia/Jakarta'));

        $live = $this->createProgressFixture(
            '2026-07-24',
            '14:00:00',
            '15:00:00',
            11,
            'Leg Day',
            'payment_verified',
            3,
            6
        );
        $unverified = $this->createProgressFixture(
            '2026-07-24',
            '12:00:00',
            '13:00:00',
            92,
            'Unverified Session',
            'payment_uploaded',
            5,
            6
        );
        $otherDay = $this->createProgressFixture(
            '2026-07-25',
            '10:00:00',
            '11:00:00',
            44,
            'Tomorrow Session',
            'payment_verified',
            3,
            6
        );

        $page = $this->adminGet(route('admin.bookings.index'));
        $page->assertOk()
            ->assertSeeText('Live Monitor Member')
            ->assertSeeText('With Coach Live Monitor Trainer')
            ->assertSeeText('50%')
            ->assertSeeText('Leg Day')
            ->assertSeeText('3/6 set selesai')
            ->assertDontSeeText('Unverified Session')
            ->assertDontSeeText('Tomorrow Session')
            ->assertDontSeeText('Coach Incentive Active')
            ->assertSee('12000', false);

        $response = $this->withSession(['admin_user_id' => $this->admin->id])
            ->getJson(route('admin.bookings.live-progress'));
        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $live->id)
            ->assertJsonPath('data.0.member_name', 'Live Monitor Member')
            ->assertJsonPath('data.0.coach_name', 'Live Monitor Trainer')
            ->assertJsonPath('data.0.progress', 50)
            ->assertJsonPath('data.0.session_name', 'Leg Day')
            ->assertJsonPath('data.0.completed_sets', 3)
            ->assertJsonPath('data.0.total_sets', 6)
            ->assertJsonPath('data.0.completed_exercises', 0)
            ->assertJsonPath('data.0.total_exercises', 1)
            ->assertJsonPath('data.0.status', 'active')
            ->assertJsonMissing(['id' => $unverified->id])
            ->assertJsonMissing(['id' => $otherDay->id]);
    }

    public function test_member_ready_paid_session_is_live_at_zero_progress(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-07-24 08:30:00', 'Asia/Jakarta'));
        $ready = $this->createProgressFixture(
            '2026-07-24',
            '16:00:00',
            '17:00:00',
            0,
            'Ready Session',
            'payment_verified',
            0,
            6,
            true
        );

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->getJson(route('admin.bookings.live-progress'))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $ready->id)
            ->assertJsonPath('data.0.progress', 0)
            ->assertJsonPath('data.0.session_name', 'Ready Session');
    }

    public function test_admin_sees_overdue_payment_verification_with_trainer_contact_and_proof(): void
    {
        Storage::fake('public');
        $trainerUser = $this->createUser('trainer', 'Overdue Contact Trainer');
        $trainerUser->update(['phone' => '081234567890']);
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'general_fitness',
            'price_per_session' => 100000,
        ]);
        $memberUser = $this->createUser('member', 'Overdue Payment Member');
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('OVERDUE-'),
        ]);
        Storage::disk('public')->put('payment-proofs/overdue.jpg', 'proof');
        $booking = Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'session_title' => 'Overdue proof admin alert',
            'session_date' => now()->addDay()->toDateString(),
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio A',
            'session_count' => 1,
            'price_per_session_snapshot' => 100000,
            'total_amount_snapshot' => 100000,
            'status' => 'payment_uploaded',
            'expired_at' => now()->subMinutes(75),
            'payment_proof_path' => 'payment-proofs/overdue.jpg',
            'payment_proof_uploaded_at' => now()->subHours(2),
        ]);

        $response = $this->adminGet(route('admin.bookings.index', ['status' => 'dikonfirmasi']));
        $response->assertOk()
            ->assertSeeText('Verifikasi Pembayaran Terlambat')
            ->assertSeeText('Overdue Payment Member')
            ->assertSeeText('Overdue Contact Trainer')
            ->assertSeeText('081234567890')
            ->assertSeeText($trainerUser->email)
            ->assertSeeText('1 jam 15 menit')
            ->assertSeeText('Lihat Booking')
            ->assertSeeText('Bukti');

        $this->assertSame('payment_uploaded', $booking->fresh()->status);
        $this->assertTrue(app(BookingRequestExpiryService::class)
            ->isPaymentVerificationOverdue($booking->fresh()));
    }

    private function createProgressFixture(
        string $date,
        string $start,
        string $end,
        float $progress,
        string $focus,
        string $bookingStatus = 'payment_verified',
        int $completedSets = 1,
        int $totalSets = 2,
        bool $memberReady = false
    ): TrainerSessionProgress {
        $booking = $this->createBooking($bookingStatus, $date, $start, $end);
        if ($bookingStatus === 'payment_verified') {
            $booking->update(['payment_verified_at' => now()]);
        }
        $reservation = BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => 1,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'trainer_schedule_date_id' => $this->scheduleDate($date)->id,
            'session_date' => $date,
            'start_time' => $start,
            'end_time' => $end,
            'session_duration_minutes' => 60,
            'status' => BookingSessionReservation::STATUS_RESERVED,
        ]);
        $program = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'booking_id' => $booking->id,
            'title' => 'Live Program '.uniqid(),
            'status' => 'active',
        ]);
        $session = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'booking_session_reservation_id' => $reservation->id,
            'sequence_order' => 1,
            'title' => $focus,
            'focus' => $focus,
            'status' => 'active',
            'member_ready' => $memberReady,
            'member_ready_at' => $memberReady ? now() : null,
        ]);

        $exercise = TrainingProgramSessionExercise::create([
            'training_program_session_id' => $session->id,
            'sequence_order' => 1,
            'custom_name' => 'Fixture Exercise',
            'custom_target_muscle' => 'Legs',
            'sets' => $totalSets,
            'reps' => 10,
            'status' => 'active',
        ]);
        $sessionProgress = TrainerSessionProgress::create([
            'training_program_id' => $program->id,
            'training_program_session_id' => $session->id,
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $this->member->id,
            'progress_percent' => $progress,
            'status' => 'active',
        ]);
        TrainerSessionProgressExercise::create([
            'trainer_session_progress_id' => $sessionProgress->id,
            'training_program_session_exercise_id' => $exercise->id,
            'completed_sets' => $completedSets,
            'total_sets' => $totalSets,
            'status' => $completedSets >= $totalSets ? 'complete' : 'active',
            'last_marked_at' => $completedSets > 0 ? now() : null,
        ]);

        return $sessionProgress;
    }

    private function createBooking(string $status, string $date, string $start, string $end): Booking
    {
        return Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Monitoring Session '.uniqid(),
            'session_date' => $date,
            'start_time' => $start,
            'end_time' => $end,
            'session_duration_minutes' => 60,
            'location' => 'EggGym Studio',
            'session_count' => 1,
            'status' => $status,
        ]);
    }

    private function createUser(string $roleName, string $name, ?string $avatar = null): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid(strtolower($roleName).'_monitor_', true).'@example.test',
            'phone' => '08'.random_int(100000000, 999999999),
            'password' => 'password123',
            'avatar_url' => $avatar,
            'status' => 'active',
        ]);
    }

    private function scheduleDate(string $date): TrainerScheduleDate
    {
        return TrainerScheduleDate::firstOrCreate(
            [
                'trainer_profile_id' => $this->trainer->id,
                'schedule_date' => $date,
            ],
            [
                'state' => 'open',
                'source' => 'manual',
                'template_version' => 1,
                'lock_version' => 1,
            ]
        );
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }
}
