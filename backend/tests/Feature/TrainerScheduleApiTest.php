<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerScheduleApiTest extends TestCase
{
    use DatabaseTransactions;

    private TrainerProfile $trainer;

    protected function setUp(): void
    {
        parent::setUp();
        CarbonImmutable::setTestNow(CarbonImmutable::create(2026, 7, 21, 6, 0, 0, 'Asia/Jakarta'));

        $role = Role::firstOrCreate(['name' => 'trainer']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => 'Schedule API Trainer',
            'email' => uniqid('schedule_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Schedule testing',
        ]);
        Sanctum::actingAs($user, [], 'sanctum');

        foreach (range(1, 7) as $day) {
            GymOperationHour::updateOrCreate(
                ['day_order' => $day],
                [
                    'day_name' => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][$day - 1],
                    'open_time' => '07:00:00',
                    'close_time' => '21:00:00',
                    'is_closed' => false,
                ]
            );
        }
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_schedule_supports_multiple_shifts_and_get_always_returns_seven_days(): void
    {
        $payload = $this->emptyWeek();
        $payload['days'][0] = [
            'day_of_week' => 1,
            'enabled' => true,
            'shifts' => [
                ['start_time' => '08:00', 'end_time' => '11:00'],
                ['start_time' => '14:00', 'end_time' => '18:00'],
            ],
        ];

        $this->putJson('/api/v1/trainer/schedule', $payload)
            ->assertOk()
            ->assertJsonPath('data.timezone', 'Asia/Jakarta')
            ->assertJsonCount(7, 'data.days')
            ->assertJsonPath('data.days.0.enabled', true)
            ->assertJsonPath('data.days.0.shifts.0.session_duration_minutes', 180)
            ->assertJsonCount(2, 'data.days.0.shifts')
            ->assertJsonStructure(['data' => ['days' => [['shifts' => [['id']]]]]]);

        $this->getJson('/api/v1/trainer/schedule')
            ->assertOk()
            ->assertJsonCount(7, 'data.days')
            ->assertJsonPath('data.days.0.shifts.1.start_time', '14:00');
    }

    public function test_put_replaces_all_existing_shifts(): void
    {
        $first = $this->emptyWeek();
        $first['days'][0] = [
            'day_of_week' => 1,
            'enabled' => true,
            'shifts' => [['start_time' => '08:00', 'end_time' => '12:00']],
        ];
        $this->putJson('/api/v1/trainer/schedule', $first)->assertOk();

        $replacement = $this->emptyWeek();
        $replacement['days'][1] = [
            'day_of_week' => 2,
            'enabled' => true,
            'shifts' => [['start_time' => '13:00', 'end_time' => '17:00']],
        ];
        $this->putJson('/api/v1/trainer/schedule', $replacement)->assertOk();

        $this->assertDatabaseMissing('trainer_schedules', [
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
        ]);
        $this->assertDatabaseHas('trainer_schedules', [
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 2,
            'start_time' => '13:00:00',
            'session_duration_minutes' => 240,
        ]);
    }

    public function test_template_put_regenerates_generated_dates_and_preserves_manual_dates(): void
    {
        $manual = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => now('Asia/Jakarta')->addDays(3)->toDateString(),
            'state' => 'closed',
            'source' => 'manual',
            'overridden_at' => now(),
            'overridden_by_user_id' => $this->trainer->user_id,
            'lock_version' => 3,
        ]);
        $beforeVersion = (int) $this->trainer->refresh()->schedule_template_version;
        $payload = $this->emptyWeek();
        $payload['days'][0] = [
            'day_of_week' => 1,
            'enabled' => true,
            'shifts' => [['start_time' => '08:00', 'end_time' => '12:00']],
        ];

        $this->putJson('/api/v1/trainer/schedule', $payload)
            ->assertOk()
            ->assertJsonPath('data.template_version', $beforeVersion + 1)
            ->assertJsonPath('data.regeneration.manual_skipped', 1);

        $manual->refresh();
        $this->assertSame('manual', $manual->source);
        $this->assertSame('closed', $manual->state);
        $this->assertSame(3, $manual->lock_version);
        $this->assertDatabaseHas('trainer_schedule_dates', [
            'trainer_profile_id' => $this->trainer->id,
            'source' => 'generated',
            'template_version' => $beforeVersion + 1,
        ]);
    }

    public function test_template_put_conflict_rolls_back_template_version_shifts_and_generated_dates(): void
    {
        $this->trainer->schedules()->create([
            'day_of_week' => 2,
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ]);
        $date = CarbonImmutable::parse('2026-07-28', TrainerScheduleMaterializer::TIMEZONE);
        app(TrainerScheduleMaterializer::class)->materializeTrainer($this->trainer, $date, $date);
        $generated = TrainerScheduleDate::with('shifts')
            ->where('trainer_profile_id', $this->trainer->id)
            ->whereDate('schedule_date', $date->toDateString())
            ->firstOrFail();
        $memberUser = User::create([
            'name' => 'Template Rollback Member',
            'email' => uniqid('template_rollback_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('TPL-ROLLBACK-'),
        ]);
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $generated->id,
            'session_title' => 'Template rollback booking',
            'session_date' => $date->toDateString(),
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'confirmed',
        ]);
        $beforeVersion = (int) $this->trainer->refresh()->schedule_template_version;
        $beforeTemplate = $this->trainer->schedules()->get(['day_of_week', 'start_time', 'end_time'])->toArray();
        $beforeDate = [
            'state' => $generated->state,
            'source' => $generated->source,
            'template_version' => $generated->template_version,
            'lock_version' => $generated->lock_version,
            'shifts' => $generated->shifts->map(fn ($shift) => [
                (string) $shift->start_time,
                (string) $shift->end_time,
            ])->all(),
        ];
        $replacement = $this->emptyWeek();
        $replacement['days'][1] = [
            'day_of_week' => 2,
            'enabled' => true,
            'shifts' => [['start_time' => '10:00', 'end_time' => '16:00']],
        ];

        $this->putJson('/api/v1/trainer/schedule', $replacement)
            ->assertStatus(409)
            ->assertJsonPath('success', false);

        $this->assertSame($beforeVersion, (int) $this->trainer->refresh()->schedule_template_version);
        $this->assertSame($beforeTemplate, $this->trainer->schedules()->get([
            'day_of_week',
            'start_time',
            'end_time',
        ])->toArray());
        $generated->refresh()->load('shifts');
        $this->assertSame($beforeDate, [
            'state' => $generated->state,
            'source' => $generated->source,
            'template_version' => $generated->template_version,
            'lock_version' => $generated->lock_version,
            'shifts' => $generated->shifts->map(fn ($shift) => [
                (string) $shift->start_time,
                (string) $shift->end_time,
            ])->all(),
        ]);
    }

    public function test_schedule_rejects_invalid_shape_overlap_boundaries_and_closed_days(): void
    {
        $duplicateDays = $this->emptyWeek();
        $duplicateDays['days'][6]['day_of_week'] = 1;
        $this->putJson('/api/v1/trainer/schedule', $duplicateDays)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('days.6.day_of_week');

        $overlap = $this->emptyWeek();
        $overlap['days'][0] = [
            'day_of_week' => 1,
            'enabled' => true,
            'shifts' => [
                ['start_time' => '08:15', 'end_time' => '11:00'],
                ['start_time' => '10:30', 'end_time' => '12:00'],
            ],
        ];
        $this->putJson('/api/v1/trainer/schedule', $overlap)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['days.0.shifts.0', 'days.0.shifts.1']);

        GymOperationHour::where('day_order', 7)->update([
            'open_time' => null,
            'close_time' => null,
            'is_closed' => true,
        ]);
        $closed = $this->emptyWeek();
        $closed['days'][6] = [
            'day_of_week' => 7,
            'enabled' => true,
            'shifts' => [['start_time' => '08:00', 'end_time' => '10:00']],
        ];
        $this->putJson('/api/v1/trainer/schedule', $closed)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('days.6.enabled');

        $legacyDuration = $this->emptyWeek();
        $legacyDuration['days'][0] = [
            'day_of_week' => 1,
            'enabled' => true,
            'shifts' => [[
                'start_time' => '08:00',
                'end_time' => '10:00',
                'session_duration_minutes' => 45,
            ]],
        ];
        $this->putJson('/api/v1/trainer/schedule', $legacyDuration)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('days.0.shifts.0');
    }

    private function emptyWeek(): array
    {
        return [
            'days' => collect(range(1, 7))->map(fn (int $day) => [
                'day_of_week' => $day,
                'enabled' => false,
                'shifts' => [],
            ])->all(),
        ];
    }
}
