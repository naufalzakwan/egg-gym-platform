<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\User;
use App\Services\TrainerScheduleMaterializer;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerScheduleDateApiTest extends TestCase
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
            'name' => 'Date API Trainer',
            'email' => uniqid('date_api_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $user->id,
            'specialty' => 'Date API testing',
        ]);
        $this->trainer->schedules()->create([
            'day_of_week' => 2,
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ]);
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
        Sanctum::actingAs($user, [], 'sanctum');
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_month_override_closed_and_reset_to_template(): void
    {
        $month = $this->getJson('/api/v1/trainer/schedule-dates?month=2026-07')
            ->assertOk()
            ->assertJsonCount(11, 'data.dates')
            ->assertJsonPath('data.dates.0.date', '2026-07-21')
            ->assertJsonPath('data.timezone', 'Asia/Jakarta');
        $date = collect($month->json('data.dates'))->firstWhere('date', '2026-07-28');
        $this->assertSame('generated', $date['source']);
        $this->assertSame('08:00', $date['shifts'][0]['start_time']);
        $this->assertSame(480, $date['shifts'][0]['session_duration_minutes']);

        $override = $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'override',
            'lock_version' => $date['lock_version'],
            'shifts' => [['start_time' => '10:00', 'end_time' => '14:00']],
        ])->assertOk()
            ->assertJsonPath('data.source', 'manual')
            ->assertJsonPath('data.state', 'open')
            ->assertJsonPath('data.shifts.0.start_time', '10:00')
            ->assertJsonPath('data.shifts.0.session_duration_minutes', 240);

        $closed = $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'closed',
            'lock_version' => $override->json('data.lock_version'),
            'shifts' => [],
        ])->assertOk()
            ->assertJsonPath('data.source', 'manual')
            ->assertJsonPath('data.state', 'closed')
            ->assertJsonCount(0, 'data.shifts');

        $this->postJson('/api/v1/trainer/schedule-dates/2026-07-28/reset', [
            'lock_version' => $closed->json('data.lock_version'),
        ])->assertOk()
            ->assertJsonPath('data.source', 'generated')
            ->assertJsonPath('data.state', 'open')
            ->assertJsonPath('data.shifts.0.start_time', '08:00')
            ->assertJsonPath('data.shifts.0.session_duration_minutes', 480);
    }

    public function test_initial_month_uses_server_today_and_next_month_starts_on_first(): void
    {
        $this->getJson('/api/v1/trainer/schedule-dates')
            ->assertOk()
            ->assertJsonPath('data.month', '2026-07')
            ->assertJsonPath('data.editable_from', '2026-07-21')
            ->assertJsonCount(11, 'data.dates')
            ->assertJsonPath('data.dates.0.date', '2026-07-21')
            ->assertJsonMissing(['date' => '2026-07-20']);

        $this->getJson('/api/v1/trainer/schedule-dates?month=2026-08')
            ->assertOk()
            ->assertJsonPath('data.month', '2026-08')
            ->assertJsonCount(31, 'data.dates')
            ->assertJsonPath('data.dates.0.date', '2026-08-01');
    }

    public function test_stale_lock_version_is_rejected(): void
    {
        app(TrainerScheduleMaterializer::class)->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta'),
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta')
        );

        $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'closed',
            'lock_version' => 99,
            'shifts' => [],
        ])->assertStatus(409);
    }

    public function test_override_accepts_interval_only_and_rejects_legacy_duration(): void
    {
        app(TrainerScheduleMaterializer::class)->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta'),
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta')
        );
        $parent = $this->trainer->scheduleDates()->whereDate('schedule_date', '2026-07-28')->firstOrFail();

        $updated = $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'override',
            'lock_version' => $parent->lock_version,
            'shifts' => [['start_time' => '10:00', 'end_time' => '14:00']],
        ])->assertOk()
            ->assertJsonPath('data.shifts.0.session_duration_minutes', 240);

        $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'override',
            'lock_version' => $updated->json('data.lock_version'),
            'shifts' => [[
                'start_time' => '10:00',
                'end_time' => '14:00',
                'session_duration_minutes' => 300,
            ]],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('shifts.0');
    }

    public function test_override_cannot_invalidate_blocking_booking(): void
    {
        app(TrainerScheduleMaterializer::class)->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta'),
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta')
        );
        $parent = $this->trainer->scheduleDates()->whereDate('schedule_date', '2026-07-28')->firstOrFail();
        $before = [
            'state' => $parent->state,
            'source' => $parent->source,
            'lock_version' => $parent->lock_version,
            'shifts' => $parent->shifts()->orderBy('start_time')->pluck('start_time', 'end_time')->all(),
        ];
        $memberUser = User::create([
            'name' => 'Date Conflict Member',
            'email' => uniqid('date_conflict_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('DATE-CONFLICT-'),
        ]);
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $parent->id,
            'session_title' => 'Protected booking',
            'session_date' => '2026-07-28',
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'confirmed',
        ]);

        $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'closed',
            'lock_version' => $parent->lock_version,
            'shifts' => [],
        ])->assertStatus(409);

        $parent->refresh();
        $this->assertSame($before, [
            'state' => $parent->state,
            'source' => $parent->source,
            'lock_version' => $parent->lock_version,
            'shifts' => $parent->shifts()->orderBy('start_time')->pluck('start_time', 'end_time')->all(),
        ]);
    }

    public function test_opening_current_month_does_not_rematerialize_historical_booked_date(): void
    {
        $historical = $this->trainer->scheduleDates()->create([
            'schedule_date' => '2026-07-02',
            'state' => 'open',
            'source' => 'generated',
            'lock_version' => 1,
        ]);
        $member = $this->createMember('Historical Date');
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $historical->id,
            'session_title' => 'Historical booking',
            'session_date' => '2026-07-02',
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'payment_verified',
        ]);

        $this->getJson('/api/v1/trainer/schedule-dates?month=2026-07')
            ->assertOk()
            ->assertJsonCount(11, 'data.dates')
            ->assertJsonMissing(['date' => '2026-07-02']);
    }

    public function test_only_protected_shift_is_locked_and_unrelated_shift_can_be_edited(): void
    {
        app(TrainerScheduleMaterializer::class)->materializeTrainer(
            $this->trainer,
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta'),
            CarbonImmutable::parse('2026-07-28', 'Asia/Jakarta')
        );
        $parent = $this->trainer->scheduleDates()
            ->whereDate('schedule_date', '2026-07-28')->firstOrFail();
        $override = $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'override',
            'lock_version' => $parent->lock_version,
            'shifts' => [
                ['start_time' => '08:00', 'end_time' => '10:00'],
                ['start_time' => '14:00', 'end_time' => '16:00'],
            ],
        ])->assertOk();
        $member = $this->createMember('Per Shift Lock');
        Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'trainer_schedule_date_id' => $parent->id,
            'session_title' => 'Protected first shift',
            'session_date' => '2026-07-28',
            'start_time' => '08:00:00',
            'end_time' => '10:00:00',
            'session_duration_minutes' => 120,
            'location' => 'Studio A',
            'status' => 'confirmed',
        ]);

        $date = collect($this->getJson('/api/v1/trainer/schedule-dates?month=2026-07')
            ->assertOk()->json('data.dates'))->firstWhere('date', '2026-07-28');
        $this->assertTrue($date['has_blockers']);
        $this->assertFalse($date['can_close']);
        $this->assertTrue($date['shifts'][0]['is_locked']);
        $this->assertSame(['legacy_booking'], $date['shifts'][0]['blocking_types']);
        $this->assertFalse($date['shifts'][1]['is_locked']);

        $this->putJson('/api/v1/trainer/schedule-dates/2026-07-28', [
            'mode' => 'override',
            'lock_version' => $date['lock_version'],
            'shifts' => [
                ['start_time' => '08:00', 'end_time' => '10:00'],
                ['start_time' => '16:00', 'end_time' => '18:00'],
            ],
        ])->assertOk()
            ->assertJsonPath('data.shifts.0.is_locked', true)
            ->assertJsonPath('data.shifts.1.start_time', '16:00')
            ->assertJsonPath('data.shifts.1.is_locked', false);
    }

    private function createMember(string $name): MemberProfile
    {
        $memberUser = User::create([
            'name' => $name,
            'email' => uniqid('schedule_date_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('SCHEDULE-DATE-'),
        ]);
    }
}
