<?php

namespace Tests\Feature;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerSchedule;
use App\Models\User;
use App\Services\Booking\BookingScheduleService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BookingScheduleCollisionTest extends TestCase
{
    use DatabaseTransactions;

    private BookingScheduleService $service;

    private TrainerProfile $trainer;

    private MemberProfile $firstMember;

    private MemberProfile $secondMember;

    private Role $memberRole;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = app(BookingScheduleService::class);
        $suffix = uniqid('collision_', true);
        $this->memberRole = Role::firstOrCreate(['name' => 'member']);

        $trainerUser = User::create([
            'name' => 'Trainer Collision Test',
            'email' => "trainer_{$suffix}@example.test",
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Collision testing',
            'price_per_session' => 100000,
        ]);

        foreach (range(1, 7) as $day) {
            GymOperationHour::updateOrCreate(
                ['day_order' => $day],
                [
                    'day_name' => CarbonImmutable::now()->startOfWeek()->addDays($day - 1)->format('l'),
                    'open_time' => '07:00:00',
                    'close_time' => '22:00:00',
                    'is_closed' => false,
                ]
            );
            TrainerSchedule::create([
                'trainer_profile_id' => $this->trainer->id,
                'day_of_week' => $day,
                'start_time' => '07:00:00',
                'end_time' => '22:00:00',
            ]);
        }

        $this->firstMember = $this->createMember("first_{$suffix}@example.test", "TEST-A-{$suffix}");
        $this->secondMember = $this->createMember("second_{$suffix}@example.test", "TEST-B-{$suffix}");
    }

    public function test_two_members_cannot_book_same_trainer_and_interval(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(10)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [['10:00:00', '11:30:00']]);

        $first = $this->service->create(
            $this->attributes($this->firstMember->id, $date, '10:00:00', '11:30:00')
        );

        try {
            $this->service->create(
                $this->attributes($this->secondMember->id, $date, '10:00:00', '11:30:00')
            );
            $this->fail('Member kedua seharusnya ditolak karena slot trainer bertabrakan.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
            $this->assertStringContainsString('Jadwal trainer sudah terisi', $exception->getMessage());
        }

        $this->assertDatabaseHas('bookings', ['id' => $first->id]);
        $this->assertSame(
            1,
            Booking::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('session_date', $date)
                ->count()
        );
    }

    public function test_exact_fifteen_minute_gap_is_allowed(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(11)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [['09:30:00', '11:00:00']]);

        Booking::create($this->attributes($this->firstMember->id, $date, '07:45:00', '09:15:00'));
        $second = $this->service->create(
            $this->attributes($this->secondMember->id, $date, '09:30:00', '11:00:00')
        );

        $this->assertDatabaseHas('bookings', ['id' => $second->id]);
    }

    public function test_member_booking_endpoint_returns_conflict_for_second_member(): void
    {
        $suffix = uniqid('endpoint_', true);
        $first = $this->createMember("endpoint_first_{$suffix}@example.test", "END-A-{$suffix}");
        $second = $this->createMember("endpoint_second_{$suffix}@example.test", "END-B-{$suffix}");
        $this->activateMembership($first, $suffix.'_first');
        $this->activateMembership($second, $suffix.'_second');

        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(13)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [['13:00:00', '14:30:00']]);
        $payload = [
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Endpoint Collision Test',
            'location' => 'Studio A',
            'session_count' => 1,
            'reservations' => [[
                'session_date' => $date,
                'start_time' => '13:00:00',
                'end_time' => '14:30:00',
            ]],
        ];

        Sanctum::actingAs($first->user, [], 'sanctum');
        $this->postJson('/api/v1/member/bookings', $payload)
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        Sanctum::actingAs($second->user, [], 'sanctum');
        $this->postJson('/api/v1/member/bookings', $payload)
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath(
                'message',
                'Jadwal trainer sudah terisi atau terlalu dekat dengan sesi lain. Silakan pilih slot lain.'
            );

        $this->assertSame(
            1,
            Booking::query()
                ->where('trainer_profile_id', $this->trainer->id)
                ->whereDate('session_date', $date)
                ->where('start_time', '13:00:00')
                ->count()
        );
    }

    public function test_gap_under_fifteen_minutes_is_rejected(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(12)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [['09:30:00', '11:00:00']]);

        Booking::create($this->attributes($this->firstMember->id, $date, '07:46:00', '09:16:00'));

        $this->expectException(BookingScheduleException::class);
        $this->service->create(
            $this->attributes($this->secondMember->id, $date, '09:30:00', '11:00:00')
        );
    }

    public function test_reschedule_cannot_move_booking_into_an_occupied_interval(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(14)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [
            ['10:00:00', '11:30:00'],
            ['10:30:00', '12:00:00'],
            ['14:00:00', '15:30:00'],
        ]);
        $occupied = $this->service->create(
            $this->attributes($this->firstMember->id, $date, '10:00:00', '11:30:00')
        );
        $candidate = $this->service->create(
            $this->attributes($this->secondMember->id, $date, '14:00:00', '15:30:00')
        );

        try {
            $this->service->reschedule(
                $candidate,
                [
                    'new_session_date' => $date,
                    'new_start_time' => '10:30:00',
                    'new_end_time' => '12:00:00',
                    'reason' => 'Collision test',
                ],
                ['pending'],
                'member_note',
                expectedMemberProfileId: $this->secondMember->id
            );
            $this->fail('Reschedule overlap seharusnya ditolak.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
        }

        $candidate->refresh();
        $this->assertSame('14:00:00', (string) $candidate->start_time);
        $this->assertDatabaseHas('bookings', ['id' => $occupied->id]);
    }

    public function test_reassign_cannot_move_booking_to_busy_trainer(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(15)
            ->toDateString();
        $this->setManualDate($this->trainer, $date, [
            ['10:00:00', '11:30:00'],
            ['10:30:00', '12:00:00'],
        ]);
        $this->service->create(
            $this->attributes($this->firstMember->id, $date, '10:00:00', '11:30:00')
        );

        $otherTrainerUser = User::create([
            'name' => 'Other Trainer Collision Test',
            'email' => uniqid('other_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $otherTrainer = TrainerProfile::create([
            'user_id' => $otherTrainerUser->id,
            'specialty' => 'Other collision testing',
            'price_per_session' => 100000,
        ]);
        $candidate = Booking::create(array_merge(
            $this->attributes($this->secondMember->id, $date, '10:30:00', '12:00:00'),
            ['trainer_profile_id' => $otherTrainer->id]
        ));

        try {
            $this->service->reassign($candidate, $this->trainer->id);
            $this->fail('Reassign ke trainer sibuk seharusnya ditolak.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
        }

        $this->assertSame($otherTrainer->id, $candidate->refresh()->trainer_profile_id);
    }

    public function test_today_past_time_is_rejected_in_jakarta_timezone(): void
    {
        $now = CarbonImmutable::create(2026, 7, 20, 15, 0, 0, BookingScheduleService::TIMEZONE);
        CarbonImmutable::setTestNow($now);

        try {
            $this->service->create(
                $this->attributes(
                    $this->firstMember->id,
                    $now->toDateString(),
                    '12:00:00',
                    '13:30:00'
                )
            );
            $this->fail('Jadwal hari ini yang sudah lewat seharusnya ditolak.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame('Jadwal sesi harus berada di masa mendatang.', $exception->getMessage());
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_booking_uses_concrete_date_override_and_links_parent(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)
            ->addDays(16)
            ->toDateString();
        $day = CarbonImmutable::parse($date, BookingScheduleService::TIMEZONE)->dayOfWeekIso;
        $this->trainer->schedules()->create([
            'day_of_week' => $day,
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ]);
        $parent = \App\Models\TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => $date,
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $parent->shifts()->create([
            'start_time' => '10:00:00',
            'end_time' => '14:00:00',
        ]);

        $booking = $this->service->create(
            $this->attributes($this->firstMember->id, $date, '10:00:00', '14:00:00')
        );
        $this->assertSame($parent->id, $booking->trainer_schedule_date_id);

        try {
            $this->service->create(
                $this->attributes($this->secondMember->id, $date, '08:00:00', '09:30:00')
            );
            $this->fail('Template interval di luar concrete override seharusnya ditolak.');
        } catch (BookingScheduleException $exception) {
            $this->assertStringContainsString('shift trainer', $exception->getMessage());
        }
    }

    public function test_create_and_reschedule_require_exact_shift_and_derive_snapshot_duration(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)->addDays(17);
        $this->setManualMixedDurationDate($this->trainer, $date->toDateString());

        $sixty = $this->service->create(
            $this->attributes($this->firstMember->id, $date->toDateString(), '08:00:00', '11:00:00')
        );
        $this->assertSame(180, $sixty->session_duration_minutes);

        try {
            $this->service->create(
                $this->attributes($this->secondMember->id, $date->toDateString(), '08:00:00', '09:00:00')
            );
            $this->fail('A contained interval that is not the complete shift should be rejected.');
        } catch (BookingScheduleException $exception) {
            $this->assertStringContainsString('shift trainer', $exception->getMessage());
        }

        $rescheduled = $this->service->reschedule(
            $sixty,
            [
                'new_session_date' => $date->toDateString(),
                'new_start_time' => '13:00:00',
                'new_end_time' => '17:00:00',
                'reason' => 'Use exact afternoon shift',
            ],
            ['pending'],
            'member_note'
        );
        $this->assertSame(240, $rescheduled->session_duration_minutes);

        $this->expectException(BookingScheduleException::class);
        $this->service->reschedule(
            $rescheduled,
            [
                'new_session_date' => $date->toDateString(),
                'new_start_time' => '08:00:00',
                'new_end_time' => '09:00:00',
                'reason' => 'Partial shift',
            ],
            ['rescheduled'],
            'member_note'
        );
    }

    public function test_reassign_requires_exact_target_shift(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)->addDays(18)->toDateString();
        $this->setManualMixedDurationDate($this->trainer, $date);
        $booking = $this->service->create(
            $this->attributes($this->firstMember->id, $date, '08:00:00', '11:00:00')
        );
        $target = $this->createTrainerWithManualShift($date, 90);

        try {
            $this->service->reassign($booking, $target->id);
            $this->fail('Reassign to a non-exact target shift should be rejected.');
        } catch (BookingScheduleException $exception) {
            $this->assertStringContainsString('shift trainer', $exception->getMessage());
        }

        $this->assertSame($this->trainer->id, $booking->refresh()->trainer_profile_id);
        $this->assertSame(180, $booking->session_duration_minutes);
    }

    public function test_reactivation_grandfathers_booking_snapshot_when_current_shift_duration_changes(): void
    {
        $date = CarbonImmutable::now(BookingScheduleService::TIMEZONE)->addDays(19)->toDateString();
        $parent = $this->setManualMixedDurationDate($this->trainer, $date);
        $booking = Booking::create(array_merge(
            $this->attributes($this->firstMember->id, $date, '13:00:00', '14:30:00'),
            [
                'trainer_schedule_date_id' => $parent->id,
                'session_duration_minutes' => 90,
                'status' => 'cancelled',
            ]
        ));
        $parent->shifts()->where('start_time', '13:00:00')->update(['session_duration_minutes' => 60]);

        $reactivated = $this->service->transitionToBlocking($booking, ['status' => 'pending'], ['cancelled']);

        $this->assertSame('pending', $reactivated->status);
        $this->assertSame(90, $reactivated->session_duration_minutes);
    }

    private function createMember(string $email, string $memberCode): MemberProfile
    {
        $user = User::create([
            'role_id' => $this->memberRole->id,
            'name' => $memberCode,
            'email' => $email,
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => substr($memberCode, 0, 50),
            'height_cm' => 170,
            'weight_kg' => 70,
            'fitness_goal' => 'Testing',
        ]);
    }

    private function setManualMixedDurationDate(TrainerProfile $trainer, string $date): \App\Models\TrainerScheduleDate
    {
        $parent = \App\Models\TrainerScheduleDate::updateOrCreate(
            ['trainer_profile_id' => $trainer->id, 'schedule_date' => $date],
            ['state' => 'open', 'source' => 'manual', 'overridden_at' => now()]
        );
        $parent->shifts()->delete();
        $parent->shifts()->createMany([
            ['start_time' => '08:00:00', 'end_time' => '11:00:00', 'session_duration_minutes' => 180],
            ['start_time' => '13:00:00', 'end_time' => '17:00:00', 'session_duration_minutes' => 240],
        ]);

        return $parent;
    }

    private function createTrainerWithManualShift(string $date, int $duration): TrainerProfile
    {
        $user = User::create([
            'name' => 'Duration Target Trainer',
            'email' => uniqid('duration_target_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $trainer = TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Duration testing',
            'price_per_session' => 100000,
        ]);
        $parent = \App\Models\TrainerScheduleDate::create([
            'trainer_profile_id' => $trainer->id,
            'schedule_date' => $date,
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $parent->shifts()->create([
            'start_time' => '07:00:00',
            'end_time' => '22:00:00',
            'session_duration_minutes' => $duration,
        ]);

        return $trainer;
    }

    private function setManualDate(TrainerProfile $trainer, string $date, array $intervals): \App\Models\TrainerScheduleDate
    {
        $parent = \App\Models\TrainerScheduleDate::updateOrCreate(
            ['trainer_profile_id' => $trainer->id, 'schedule_date' => $date],
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

    private function attributes(
        int $memberProfileId,
        string $date,
        string $start,
        string $end
    ): array {
        return [
            'member_profile_id' => $memberProfileId,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Collision Test',
            'session_date' => $date,
            'start_time' => $start,
            'end_time' => $end,
            'session_duration_minutes' => CarbonImmutable::createFromFormat('H:i:s', $start)
                ->diffInMinutes(CarbonImmutable::createFromFormat('H:i:s', $end)),
            'location' => 'Studio A',
            'status' => 'pending',
            'member_note' => null,
            'trainer_note' => null,
        ];
    }

    private function activateMembership(MemberProfile $member, string $suffix): void
    {
        $plan = MembershipPlan::create([
            'name' => 'Collision Test Plan',
            'slug' => 'collision-test-'.$suffix,
            'price' => 1,
            'billing_period' => 'monthly',
            'is_active' => true,
        ]);

        MemberMembership::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addMonth()->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
    }
}
