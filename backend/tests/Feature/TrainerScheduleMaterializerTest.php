<?php

namespace Tests\Feature;

use App\Exceptions\BookingScheduleException;
use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class TrainerScheduleMaterializerTest extends TestCase
{
    use DatabaseTransactions;

    private TrainerProfile $trainer;

    private TrainerScheduleMaterializer $materializer;

    protected function setUp(): void
    {
        parent::setUp();
        $user = User::create([
            'name' => 'Materializer Trainer',
            'email' => uniqid('materializer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Materializer test',
        ]);
        $this->trainer->schedules()->createMany([
            ['day_of_week' => 1, 'start_time' => '08:00:00', 'end_time' => '12:00:00', 'session_duration_minutes' => 60],
            ['day_of_week' => 1, 'start_time' => '16:00:00', 'end_time' => '18:00:00', 'session_duration_minutes' => 90],
            ['day_of_week' => 1, 'start_time' => '19:00:00', 'end_time' => '20:00:00'],
        ]);
        GymOperationHour::query()->updateOrCreate(
            ['day_order' => 1],
            [
                'day_name' => 'Monday',
                'open_time' => '07:00:00',
                'close_time' => '21:30:00',
                'is_closed' => false,
            ]
        );
        $this->materializer = app(TrainerScheduleMaterializer::class);
    }

    public function test_materializes_open_multi_shift_and_explicit_closed_dates(): void
    {
        $result = $this->materializer->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE),
            CarbonImmutable::parse('2026-07-21', TrainerScheduleMaterializer::TIMEZONE)
        );

        $this->assertSame(2, $result['created']);
        $monday = TrainerScheduleDate::with('shifts')
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', '2026-07-20')
            ->firstOrFail();
        $this->assertSame('open', $monday->state);
        $this->assertSame('generated', $monday->source);
        $this->assertSame(
            ['08:00:00-12:00:00', '16:00:00-18:00:00', '19:00:00-20:00:00'],
            $monday->shifts->map(fn ($shift) => substr((string) $shift->start_time, 0, 8).'-'.substr((string) $shift->end_time, 0, 8)
            )->all()
        );
        $this->assertSame([240, 120, 60], $monday->shifts->pluck('session_duration_minutes')->all());

        $tuesday = TrainerScheduleDate::with('shifts')
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', '2026-07-21')
            ->firstOrFail();
        $this->assertSame('closed', $tuesday->state);
        $this->assertCount(0, $tuesday->shifts);
    }

    public function test_second_run_is_noop_without_duplicate_rows_or_shifts(): void
    {
        $start = CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE);
        $end = CarbonImmutable::parse('2026-07-21', TrainerScheduleMaterializer::TIMEZONE);
        $this->materializer->materializeTrainer($this->trainer, $start, $end);
        $beforeDates = TrainerScheduleDate::where('trainer_profile_id', $this->trainer->id)->count();
        $beforeShifts = TrainerScheduleDate::where('trainer_profile_id', $this->trainer->id)
            ->withCount('shifts')->get()->sum('shifts_count');

        $second = $this->materializer->materializeTrainer($this->trainer, $start, $end);

        $this->assertSame(0, $second['created']);
        $this->assertSame(0, $second['updated']);
        $this->assertSame(2, $second['unchanged']);
        $this->assertSame($beforeDates, TrainerScheduleDate::where('trainer_profile_id', $this->trainer->id)->count());
        $this->assertSame(
            $beforeShifts,
            TrainerScheduleDate::where('trainer_profile_id', $this->trainer->id)
                ->withCount('shifts')->get()->sum('shifts_count')
        );
    }

    public function test_manual_date_is_never_overwritten_by_materializer(): void
    {
        $manual = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-20',
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
            'lock_version' => 4,
        ]);
        $manual->shifts()->create([
            'start_time' => '10:00:00',
            'end_time' => '11:30:00',
            'session_duration_minutes' => 60,
        ]);

        $this->trainer->schedules()->delete();
        $this->trainer->schedules()->create([
            'day_of_week' => 1,
            'start_time' => '13:00:00',
            'end_time' => '17:00:00',
        ]);
        $this->trainer->increment('schedule_template_version');

        $result = $this->materializer->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE),
            CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE)
        );

        $this->assertSame(1, $result['manual_skipped']);
        $manual->refresh();
        $this->assertSame('manual', $manual->source);
        $this->assertSame('open', $manual->state);
        $this->assertSame(4, $manual->lock_version);
        $this->assertSame(1, $manual->shifts()->count());
        $this->assertSame('10:00:00', (string) $manual->shifts()->firstOrFail()->start_time);
        $this->assertSame(60, $manual->shifts()->firstOrFail()->session_duration_minutes);
    }

    public function test_reset_manual_override_uses_current_template_version_and_shifts(): void
    {
        $date = CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE);
        $manual = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => $date->toDateString(),
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
            'lock_version' => 6,
        ]);
        $manual->shifts()->create([
            'start_time' => '10:00:00',
            'end_time' => '11:30:00',
            'session_duration_minutes' => 60,
        ]);
        $this->trainer->schedules()->delete();
        $this->trainer->schedules()->create([
            'day_of_week' => 1,
            'start_time' => '13:00:00',
            'end_time' => '17:00:00',
            'session_duration_minutes' => 120,
        ]);
        $this->trainer->increment('schedule_template_version');
        $currentVersion = (int) $this->trainer->refresh()->schedule_template_version;

        $reset = $this->materializer->resetDateToTemplate($this->trainer, $date, 6);

        $this->assertSame('generated', $reset->source);
        $this->assertSame('open', $reset->state);
        $this->assertSame($currentVersion, $reset->template_version);
        $this->assertSame(7, $reset->lock_version);
        $this->assertSame(['13:00:00-17:00:00'], $this->shiftIntervals($reset));
        $this->assertSame([240], $reset->shifts->pluck('session_duration_minutes')->all());
    }

    public function test_generated_inactive_weekday_and_manual_closed_dates_remain_closed(): void
    {
        $manual = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-22',
            'state' => 'closed',
            'source' => 'manual',
            'overridden_at' => now(),
            'lock_version' => 2,
        ]);

        $result = $this->materializer->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-21', TrainerScheduleMaterializer::TIMEZONE),
            CarbonImmutable::parse('2026-07-22', TrainerScheduleMaterializer::TIMEZONE)
        );

        $generated = TrainerScheduleDate::with('shifts')
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', '2026-07-21')
            ->firstOrFail();
        $this->assertSame('generated', $generated->source);
        $this->assertSame('closed', $generated->state);
        $this->assertCount(0, $generated->shifts);
        $this->assertSame(1, $result['manual_skipped']);
        $this->assertSame('manual', $manual->refresh()->source);
        $this->assertSame('closed', $manual->state);
        $this->assertSame(2, $manual->lock_version);
        $this->assertSame(0, $manual->shifts()->count());
    }

    public function test_conflicting_range_regeneration_rolls_back_all_generated_date_mutations(): void
    {
        $this->trainer->schedules()->create([
            'day_of_week' => 2,
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
        ]);
        $start = CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE);
        $end = CarbonImmutable::parse('2026-07-21', TrainerScheduleMaterializer::TIMEZONE);
        $this->materializer->materializeTrainer($this->trainer, $start, $end);
        $monday = $this->date('2026-07-20');
        $tuesday = $this->date('2026-07-21');
        $member = $this->createMember();
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $tuesday->id,
            'session_title' => 'Materializer rollback booking',
            'session_date' => '2026-07-21',
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'confirmed',
        ]);
        $beforeMonday = $this->dateSnapshot($monday);
        $beforeTuesday = $this->dateSnapshot($tuesday);

        $this->trainer->schedules()->delete();
        $this->trainer->schedules()->createMany([
            ['day_of_week' => 1, 'start_time' => '10:00:00', 'end_time' => '12:00:00'],
            ['day_of_week' => 2, 'start_time' => '10:00:00', 'end_time' => '12:00:00'],
        ]);
        $this->trainer->increment('schedule_template_version');

        try {
            $this->materializer->materializeTrainer($this->trainer, $start, $end);
            $this->fail('Regeneration should reject a template that excludes a blocking booking.');
        } catch (BookingScheduleException $exception) {
            $this->assertSame(409, $exception->httpStatus);
        }

        $this->assertSame($beforeMonday, $this->dateSnapshot($monday->refresh()));
        $this->assertSame($beforeTuesday, $this->dateSnapshot($tuesday->refresh()));
    }

    public function test_materialize_all_extends_month_horizon_without_duplicates_and_preserves_manual_date(): void
    {
        $first = $this->materializer->materializeAll(
            CarbonImmutable::create(2026, 1, 31, 23, 30, 0, TrainerScheduleMaterializer::TIMEZONE)
        );
        $this->assertGreaterThanOrEqual(29, $first['dates']);
        $this->assertSame(29, $this->trainerDateCount('2026-01-31', '2026-02-28'));
        $this->assertDatabaseHas('trainer_schedule_dates', [
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-02-28',
        ]);

        $manual = $this->date('2026-02-02');
        $manual->update([
            'state' => 'closed',
            'source' => 'manual',
            'template_version' => null,
            'overridden_at' => now(),
            'lock_version' => 5,
        ]);
        $manual->shifts()->delete();

        $second = $this->materializer->materializeAll(
            CarbonImmutable::create(2026, 2, 1, 0, 5, 0, TrainerScheduleMaterializer::TIMEZONE)
        );

        $this->assertGreaterThanOrEqual(59, $second['dates']);
        $this->assertSame(60, $this->trainerDateCount('2026-01-31', '2026-03-31'));
        $this->assertSame(60, TrainerScheduleDate::query()
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereBetween('schedule_date', ['2026-01-31', '2026-03-31'])
            ->distinct('schedule_date')
            ->count('schedule_date'));
        $this->assertDatabaseHas('trainer_schedule_dates', [
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-03-31',
        ]);
        $manual->refresh();
        $this->assertSame('manual', $manual->source);
        $this->assertSame('closed', $manual->state);
        $this->assertSame(5, $manual->lock_version);
        $this->assertSame(0, $manual->shifts()->count());
    }

    public function test_legacy_template_duration_change_is_ignored(): void
    {
        $date = CarbonImmutable::parse('2026-07-20', TrainerScheduleMaterializer::TIMEZONE);
        $this->materializer->materializeTrainer($this->trainer, $date, $date);
        $generated = $this->date($date->toDateString());
        $beforeFingerprint = $generated->template_fingerprint;

        $this->trainer->schedules()->where('start_time', '08:00:00')->update([
            'session_duration_minutes' => 120,
        ]);
        $this->trainer->increment('schedule_template_version');
        $result = $this->materializer->materializeTrainer($this->trainer, $date, $date);

        $generated->refresh()->load('shifts');
        $this->assertSame(1, $result['updated']);
        $this->assertSame($beforeFingerprint, $generated->template_fingerprint);
        $this->assertSame(240, $generated->shifts->first()->session_duration_minutes);
    }

    private function date(string $date): TrainerScheduleDate
    {
        return TrainerScheduleDate::with('shifts')
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', $date)
            ->firstOrFail();
    }

    private function shiftIntervals(TrainerScheduleDate $date): array
    {
        return $date->shifts()->orderBy('start_time')->get()
            ->map(fn ($shift) => substr((string) $shift->start_time, 0, 8).'-'.substr((string) $shift->end_time, 0, 8))
            ->all();
    }

    private function dateSnapshot(TrainerScheduleDate $date): array
    {
        return [
            'state' => $date->state,
            'source' => $date->source,
            'template_version' => $date->template_version,
            'template_fingerprint' => $date->template_fingerprint,
            'operation_fingerprint' => $date->operation_fingerprint,
            'lock_version' => $date->lock_version,
            'shifts' => $this->shiftIntervals($date),
        ];
    }

    private function trainerDateCount(string $start, string $end): int
    {
        return TrainerScheduleDate::query()
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereBetween('schedule_date', [$start, $end])
            ->count();
    }

    private function createMember(): MemberProfile
    {
        $user = User::create([
            'name' => 'Materializer Member',
            'email' => uniqid('materializer_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid('MAT-MEMBER-'),
        ]);
    }
}
