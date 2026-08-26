<?php

namespace Tests\Feature;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\GymOperationHour;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use App\Services\Booking\BookingScheduleService;
use App\Services\TrainerAvailabilityService;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BookingSessionReservationTest extends TestCase
{
    use DatabaseTransactions;

    private BookingScheduleService $service;

    private TrainerProfile $trainer;

    private MemberProfile $firstMember;

    private MemberProfile $secondMember;

    protected function setUp(): void
    {
        parent::setUp();
        $now = CarbonImmutable::parse('2026-07-21T06:00:00+07:00');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);
        $this->service = app(BookingScheduleService::class);

        $trainerUser = User::create([
            'name' => 'Series Trainer',
            'email' => uniqid('series_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Reservation testing',
            'price_per_session' => 100000,
            'bank_name' => 'BCA',
            'bank_account_number' => '111222333',
            'bank_account_name' => 'Bank Trainer',
            'dana_number' => '081234567890',
            'dana_account_name' => 'DANA Trainer',
            'other_payment_method' => 'GoPay',
            'other_payment_number' => '089876543210',
            'other_payment_account_name' => 'GoPay Trainer',
        ]);
        $this->firstMember = $this->createMember('first');
        $this->secondMember = $this->createMember('second');

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
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_count_four_uses_exact_manual_dates_and_different_shifts(): void
    {
        $this->setDate('2026-07-21', [['08:00:00', '12:00:00']]);
        $this->setDate('2026-07-23', [['16:00:00', '18:00:00']]);
        $this->setDate('2026-07-25', [['08:00:00', '09:00:00']]);
        $this->setDate('2026-07-28', [['13:00:00', '17:00:00']]);
        $manual = [
            $this->selection('2026-07-21', '08:00:00', '12:00:00'),
            $this->selection('2026-07-23', '16:00:00', '18:00:00'),
            $this->selection('2026-07-25', '08:00:00', '09:00:00'),
            $this->selection('2026-07-28', '13:00:00', '17:00:00'),
        ];

        $booking = $this->service->create($this->attributes($this->firstMember, 4, $manual));

        $this->assertSame(4, $booking->sessionReservations->count());
        $this->assertSame(
            ['2026-07-21', '2026-07-23', '2026-07-25', '2026-07-28'],
            $booking->sessionReservations
                ->map(fn ($reservation) => $reservation->session_date->toDateString())
                ->all()
        );
        $this->assertSame([1, 2, 3, 4], $booking->sessionReservations->pluck('sequence_order')->all());
        $this->assertSame(
            ['08:00:00', '16:00:00', '08:00:00', '13:00:00'],
            $booking->sessionReservations->pluck('start_time')->all()
        );
        $this->assertSame('2026-07-21', $booking->session_date->toDateString());
    }

    public function test_public_trainer_specialty_maps_legacy_for_display_without_mutating_database(): void
    {
        $this->trainer->update(['specialty' => 'Bodybuilding - Nutrition']);

        $payload = collect($this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->json('data'))->firstWhere('id', $this->trainer->id);

        $this->assertSame('Bodybuilding', $payload['specialty'] ?? null);
        $this->assertSame('bodybuilding', $payload['specialty_slug'] ?? null);
        $this->assertSame('Bodybuilding - Nutrition', $this->trainer->fresh()->specialty);
    }

    public function test_public_trainer_exposes_all_specialties_with_primary_compatibility(): void
    {
        $this->trainer->update([
            'specialty' => 'Bodybuilding',
            'specialties' => ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
        ]);

        $payload = collect($this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->json('data'))->firstWhere('id', $this->trainer->id);

        $this->assertSame('Bodybuilding', $payload['specialty'] ?? null);
        $this->assertSame(
            ['Bodybuilding', 'Weight Loss', 'Powerlifting'],
            $payload['specialties'] ?? null
        );
    }

    public function test_member_endpoint_creates_requested_series_atomically(): void
    {
        foreach (range(21, 24) as $day) {
            $this->setDate("2026-07-{$day}", [['08:00:00', '12:00:00']]);
        }
        $this->firstMember->update([
            'height_cm' => 170,
            'weight_kg' => 70,
            'fitness_goal' => 'Reservation test',
        ]);
        $plan = MembershipPlan::create([
            'name' => 'Reservation Test Membership',
            'slug' => uniqid('reservation-test-'),
            'price' => 1,
            'billing_period' => 'monthly',
            'is_active' => true,
        ]);
        MemberMembership::create([
            'member_profile_id' => $this->firstMember->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addMonth()->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->firstMember->user->update(['role_id' => $memberRole->id]);
        Sanctum::actingAs($this->firstMember->user, [], 'sanctum');

        $trainerResponse = $this->getJson('/api/v1/public/trainers')->assertOk();
        $trainerPayload = collect($trainerResponse->json('data'))
            ->firstWhere('id', $this->trainer->id);
        $this->assertSame(100000, $trainerPayload['price_per_session'] ?? null);

        $response = $this->postJson('/api/v1/member/bookings', [
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Four Session API Booking',
            'location' => 'Studio A',
            'session_count' => 4,
            'reservations' => [
                $this->selection('2026-07-21', '08:00:00', '12:00:00'),
                $this->selection('2026-07-22', '08:00:00', '12:00:00'),
                $this->selection('2026-07-23', '08:00:00', '12:00:00'),
                $this->selection('2026-07-24', '08:00:00', '12:00:00'),
            ],
        ])->assertCreated()
            ->assertJsonPath('data.session_count', 4)
            ->assertJsonPath('data.price_per_session', 100000)
            ->assertJsonPath('data.total_amount', 400000)
            ->assertJsonCount(4, 'data.session_reservations');

        $bookingId = $response->json('data.id');
        $this->assertSame(4, BookingSessionReservation::query()
            ->where('booking_id', $bookingId)
            ->count());
        $this->assertDatabaseHas('bookings', [
            'id' => $bookingId,
            'session_count' => 4,
            'price_per_session_snapshot' => 100000,
            'total_amount_snapshot' => 400000,
        ]);

        $this->trainer->update(['price_per_session' => 250000]);
        Booking::query()->whereKey($bookingId)->update(['status' => 'waiting_payment']);
        $this->getJson("/api/v1/member/bookings/{$bookingId}/payment-info")
            ->assertOk()
            ->assertJsonPath('data.session_count', 4)
            ->assertJsonPath('data.price_per_session', 100000)
            ->assertJsonPath('data.total_amount', 400000)
            ->assertJsonPath('data.trainer.bank_name', 'BCA')
            ->assertJsonPath('data.trainer.bank_account_name', 'Bank Trainer')
            ->assertJsonPath('data.trainer.dana_number', '081234567890')
            ->assertJsonPath('data.trainer.dana_account_name', 'DANA Trainer')
            ->assertJsonPath('data.trainer.other_payment_method', 'GoPay')
            ->assertJsonPath('data.trainer.other_payment_number', '089876543210')
            ->assertJsonPath('data.trainer.other_payment_account_name', 'GoPay Trainer')
            ->assertJsonCount(4, 'data.session_reservations');

        Storage::fake('public');
        $this->postJson("/api/v1/member/bookings/{$bookingId}/upload-proof", [
            'payment_proof' => UploadedFile::fake()->image('proof.jpg'),
            'session_count' => 1,
        ])->assertOk()
            ->assertJsonPath('data.session_count', 4)
            ->assertJsonPath('data.total_amount', 400000);
        $this->assertDatabaseHas('bookings', [
            'id' => $bookingId,
            'session_count' => 4,
            'total_amount_snapshot' => 400000,
            'status' => 'payment_uploaded',
        ]);
    }

    public function test_same_shift_is_allowed_on_strictly_ascending_different_dates(): void
    {
        $this->setDate('2026-07-21', [['08:00:00', '12:00:00']]);
        $this->setDate('2026-07-23', [['08:00:00', '12:00:00']]);

        $booking = $this->service->create($this->attributes($this->firstMember, 2, [
            $this->selection('2026-07-21', '08:00:00', '12:00:00'),
            $this->selection('2026-07-23', '08:00:00', '12:00:00'),
        ]));

        $this->assertSame(
            ['2026-07-21', '2026-07-23'],
            $booking->sessionReservations
                ->map(fn ($reservation) => $reservation->session_date->toDateString())
                ->all()
        );
        $this->assertSame(
            ['08:00:00', '08:00:00'],
            $booking->sessionReservations->pluck('start_time')->all()
        );
    }

    public function test_count_mismatch_same_date_and_descending_dates_are_rejected_without_rows(): void
    {
        $this->setDate('2026-07-21', [['08:00:00', '12:00:00']]);
        $this->setDate('2026-07-23', [['08:00:00', '12:00:00']]);
        $bookingCount = Booking::count();
        $reservationCount = BookingSessionReservation::count();

        try {
            $this->service->create($this->attributes($this->firstMember, 3, [
                $this->selection('2026-07-21', '08:00:00', '12:00:00'),
                $this->selection('2026-07-23', '08:00:00', '12:00:00'),
            ]));
            $this->fail('Count mismatch should be rejected.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(422, $exception->httpStatus);
            $this->assertStringContainsString('Jumlah jadwal', $exception->getMessage());
        }

        $this->assertSame($bookingCount, Booking::count());
        $this->assertSame($reservationCount, BookingSessionReservation::count());

        try {
            $this->service->create($this->attributes($this->firstMember, 2, [
                $this->selection('2026-07-21', '08:00:00', '12:00:00'),
                $this->selection('2026-07-21', '16:00:00', '18:00:00'),
            ]));
            $this->fail('Different shifts on the same date should be rejected.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(422, $exception->httpStatus);
            $this->assertStringContainsString('tanggal yang berbeda', $exception->getMessage());
        }
        $this->assertSame($bookingCount, Booking::count());
        $this->assertSame($reservationCount, BookingSessionReservation::count());

        try {
            $this->service->create($this->attributes($this->firstMember, 2, [
                $this->selection('2026-07-23', '08:00:00', '12:00:00'),
                $this->selection('2026-07-21', '08:00:00', '12:00:00'),
            ]));
            $this->fail('Descending session dates should be rejected.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(422, $exception->httpStatus);
            $this->assertStringContainsString('berurutan maju', $exception->getMessage());
        }
        $this->assertSame($bookingCount, Booking::count());
        $this->assertSame($reservationCount, BookingSessionReservation::count());
    }

    public function test_middle_collision_rolls_back_whole_series_and_second_request_cannot_overlap(): void
    {
        foreach (range(21, 24) as $day) {
            $this->setDate("2026-07-{$day}", [['08:00:00', '12:00:00']]);
        }

        $legacy = Booking::create(array_merge($this->attributes($this->secondMember, 1), [
            'session_date' => '2026-07-23',
            'session_count' => 1,
        ]));
        $bookingCount = Booking::count();
        $reservationCount = BookingSessionReservation::count();
        $seriesCount = Booking::query()->whereHas('sessionReservations')->count();

        try {
            $this->service->create($this->attributes($this->firstMember, 4, $this->dailySelections(21, 24)));
            $this->fail('Middle collision should reject the whole series.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
        }

        $this->assertSame($bookingCount, Booking::count());
        $this->assertSame($reservationCount, BookingSessionReservation::count());
        $this->assertDatabaseHas('bookings', ['id' => $legacy->id]);

        $legacy->update(['status' => 'cancelled']);
        $first = $this->service->create($this->attributes($this->firstMember, 4, $this->dailySelections(21, 24)));
        $this->assertSame(4, $first->sessionReservations->count());

        try {
            $this->service->create($this->attributes($this->secondMember, 4, $this->dailySelections(21, 24)));
            $this->fail('A competing request must lose after the first series is committed.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
        }
        $this->assertSame(
            $seriesCount + 1,
            Booking::query()->whereHas('sessionReservations')->count()
        );
        $this->assertSame($reservationCount + 4, BookingSessionReservation::count());
    }

    public function test_availability_uses_children_once_and_keeps_legacy_parent_blocking(): void
    {
        foreach (range(21, 23) as $day) {
            $this->setDate("2026-07-{$day}", [['08:00:00', '12:00:00']]);
        }
        $series = $this->service->create($this->attributes($this->firstMember, 2, $this->dailySelections(21, 22)));
        $legacy = Booking::create(array_merge($this->attributes($this->secondMember, 1), [
            'session_date' => '2026-07-23',
            'session_count' => 1,
            'trainer_schedule_date_id' => $this->date('2026-07-23')->id,
        ]));

        $availability = app(TrainerAvailabilityService::class)->availability($this->trainer);
        $slotsByDate = collect($availability['weekdays'])
            ->flatMap(fn (array $weekday) => $weekday['occurrences'])
            ->keyBy('date')
            ->map(fn (array $occurrence) => collect($occurrence['slots'])->first());

        $this->assertFalse($slotsByDate['2026-07-21']['is_available']);
        $this->assertFalse($slotsByDate['2026-07-22']['is_available']);
        $this->assertFalse($slotsByDate['2026-07-23']['is_available']);
        $this->assertSame(2, $series->sessionReservations()->count());
        $this->assertSame(0, $legacy->sessionReservations()->count());

        $series->update(['status' => 'cancelled']);
        $availability = app(TrainerAvailabilityService::class)->availability($this->trainer);
        $slotsByDate = collect($availability['weekdays'])
            ->flatMap(fn (array $weekday) => $weekday['occurrences'])
            ->keyBy('date')
            ->map(fn (array $occurrence) => collect($occurrence['slots'])->first());
        $this->assertTrue($slotsByDate['2026-07-21']['is_available']);
        $this->assertTrue($slotsByDate['2026-07-22']['is_available']);
        $this->assertFalse($slotsByDate['2026-07-23']['is_available']);
    }

    private function createMember(string $name): MemberProfile
    {
        $user = User::create([
            'name' => ucfirst($name).' Series Member',
            'email' => uniqid("{$name}_series_", true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid(strtoupper($name).'-'),
        ]);
    }

    private function attributes(MemberProfile $member, int $count, ?array $reservations = null): array
    {
        $attributes = [
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Series Reservation',
            'session_date' => '2026-07-21',
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
            'location' => 'Studio A',
            'session_count' => $count,
            'status' => 'pending',
        ];
        if ($reservations !== null) {
            $attributes['reservations'] = $reservations;
        }

        return $attributes;
    }

    private function selection(string $date, string $start, string $end): array
    {
        return [
            'session_date' => $date,
            'start_time' => $start,
            'end_time' => $end,
        ];
    }

    private function dailySelections(int $startDay, int $endDay): array
    {
        return array_map(
            fn (int $day) => $this->selection("2026-07-{$day}", '08:00:00', '12:00:00'),
            range($startDay, $endDay)
        );
    }

    private function setDate(string $date, array $intervals): TrainerScheduleDate
    {
        $parent = TrainerScheduleDate::updateOrCreate(
            ['trainer_profile_id' => $this->trainer->id, 'schedule_date' => $date],
            ['state' => 'open', 'source' => 'manual', 'overridden_at' => now()]
        );
        $parent->shifts()->delete();
        $parent->shifts()->createMany(array_map(fn (array $interval) => [
            'start_time' => $interval[0],
            'end_time' => $interval[1],
            'session_duration_minutes' => CarbonImmutable::createFromFormat('H:i:s', $interval[0])
                ->diffInMinutes(CarbonImmutable::createFromFormat('H:i:s', $interval[1])),
        ], $intervals));

        return $parent;
    }

    private function date(string $date): TrainerScheduleDate
    {
        return TrainerScheduleDate::query()
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', $date)
            ->firstOrFail();
    }
}
