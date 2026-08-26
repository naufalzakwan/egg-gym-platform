<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\GymOperationHour;
use App\Models\MemberProfile;
use App\Models\TrainerProfile;
use App\Models\TrainerSchedule;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use App\Services\TrainerAvailabilityService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class TrainerAvailabilityApiTest extends TestCase
{
    use DatabaseTransactions;

    private TrainerProfile $trainer;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();

        CarbonImmutable::setTestNow(CarbonImmutable::create(2026, 7, 20, 6, 0, 0, TrainerAvailabilityService::TIMEZONE));

        $trainerUser = User::create([
            'name' => 'Availability Trainer',
            'email' => uniqid('availability_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Availability testing',
        ]);

        $memberUser = User::create([
            'name' => 'Availability Member',
            'email' => uniqid('availability_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('AVAIL-'),
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
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_availability_exposes_one_slot_per_effective_shift_without_rolling(): void
    {
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '08:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
        ]);
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '16:00:00',
            'end_time' => '17:00:00',
            'session_duration_minutes' => 90,
        ]);

        $response = $this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertOk()
            ->assertJsonPath('data.trainer_profile_id', $this->trainer->id)
            ->assertJsonPath('data.timezone', 'Asia/Jakarta')
            ->assertJsonPath('data.current_server_date', '2026-07-20')
            ->assertJsonPath('data.month_end_date', '2026-07-31')
            ->assertJsonPath('data.horizon_days', 30)
            ->assertJsonPath('data.session_duration_minutes', null)
            ->assertJsonPath('data.slot_policy', 'shift_interval')
            ->assertJsonMissingPath('data.duration_policy')
            ->assertJsonMissingPath('data.slot_interval_minutes')
            ->assertJsonPath('data.buffer_minutes', 15)
            ->assertJsonPath('data.lead_time_minutes', 120)
            ->assertJsonCount(7, 'data.weekdays')
            ->assertJsonPath('data.weekdays.0.day_of_week', 1)
            ->assertJsonPath('data.weekdays.0.schedule_enabled', true)
            ->assertJsonPath('data.weekdays.0.occurrences.0.date', '2026-07-20')
            ->assertJsonCount(2, 'data.weekdays.0.occurrences.0.effective_shifts')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.start_time', '08:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.end_time', '11:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.session_duration_minutes', 180)
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.slot_count', 1)
            ->assertJsonCount(1, 'data.weekdays.0.occurrences.0.effective_shifts.0.slot_keys')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.1.start_time', '16:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.1.end_time', '17:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.1.session_duration_minutes', 60)
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.1.slot_count', 1)
            ->assertJsonCount(1, 'data.weekdays.0.occurrences.0.effective_shifts.1.slot_keys')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.start_time', '08:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.end_time', '11:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.session_duration_minutes', 180)
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.shift_start_time', '08:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.shift_end_time', '11:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.location', 'Studio A')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.key', '2026-07-20_08:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.is_available', true)
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.unavailable_reason', null)
            ->assertJsonPath('data.weekdays.1.schedule_enabled', false);

        $mondayOccurrences = collect($response->json('data.weekdays.0.occurrences'));
        $this->assertSame(
            ['08:00:00', '16:00:00'],
            $mondayOccurrences->first()['slots']
            ? collect($mondayOccurrences->first()['slots'])->pluck('start_time')->all()
            : []);
    }

    public function test_availability_intersects_operation_hours_and_applies_lead_blocking_and_buffer(): void
    {
        GymOperationHour::where('day_order', 1)->update([
            'open_time' => '08:30:00',
            'close_time' => '12:00:00',
        ]);
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '07:00:00',
            'end_time' => '13:00:00',
        ]);
        Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Blocking booking',
            'session_date' => '2026-07-20',
            'start_time' => '10:30:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'confirmed',
        ]);

        $response = $this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertOk()
            ->assertJsonMissingPath('data.weekdays.0.occurrences.0.slots.0.booking_id')
            ->assertJsonMissingPath('data.weekdays.0.occurrences.0.slots.0.member_profile_id');
        $slots = collect($response->json('data.weekdays.0.occurrences.0.slots'));

        $this->assertSame(
            [],
            $slots->where('is_available', true)->pluck('start_time')->all()
        );
        $this->assertSame(
            ['08:30:00'],
            $slots->where('is_available', false)->pluck('start_time')->all()
        );
        $this->assertSame(
            ['booked'],
            $slots->where('is_available', false)->pluck('unavailable_reason')->unique()->values()->all()
        );
    }

    public function test_availability_keeps_open_occurrence_when_all_slots_are_blocked_and_rejects_inactive_trainer(): void
    {
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
        ]);
        Booking::create([
            'member_profile_id' => $this->member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Only slot blocked',
            'session_date' => '2026-07-20',
            'start_time' => '08:00:00',
            'end_time' => '09:30:00',
            'session_duration_minutes' => 90,
            'location' => 'Studio A',
            'status' => 'pending',
        ]);

        $response = $this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertOk()
            ->assertJsonPath('data.weekdays.0.schedule_enabled', true)
            ->assertJsonPath('data.weekdays.0.occurrences.0.date', '2026-07-20')
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.is_available', false)
            ->assertJsonPath('data.weekdays.0.occurrences.0.slots.0.unavailable_reason', 'booked');
        $occurrences = collect($response->json('data.weekdays.0.occurrences'));
        $this->assertTrue($occurrences->contains('date', '2026-07-20'));

        $this->trainer->user->update(['status' => 'inactive']);
        $this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertNotFound();
    }

    public function test_open_occurrence_is_returned_with_empty_slots_when_lead_time_removes_all_candidates(): void
    {
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '07:00:00',
            'end_time' => '08:30:00',
        ]);

        $this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertOk()
            ->assertJsonPath('data.weekdays.0.occurrences.0.date', '2026-07-20')
            ->assertJsonCount(1, 'data.weekdays.0.occurrences.0.effective_shifts')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.start_time', '07:00:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.end_time', '08:30:00')
            ->assertJsonPath('data.weekdays.0.occurrences.0.effective_shifts.0.slot_count', 0)
            ->assertJsonCount(0, 'data.weekdays.0.occurrences.0.slots');
    }

    public function test_availability_uses_manual_concrete_date_instead_of_weekday_template(): void
    {
        TrainerSchedule::create([
            'trainer_profile_id' => $this->trainer->id,
            'day_of_week' => 1,
            'start_time' => '08:00:00',
            'end_time' => '16:00:00',
        ]);
        $parent = TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => '2026-07-20',
            'state' => 'open',
            'source' => 'manual',
            'overridden_at' => now(),
        ]);
        $parent->shifts()->create([
            'start_time' => '10:00:00',
            'end_time' => '14:00:00',
        ]);

        $slots = collect($this->getJson("/api/v1/public/trainers/{$this->trainer->id}/availability")
            ->assertOk()
            ->json('data.weekdays.0.occurrences.0.slots'));

        $this->assertSame('10:00:00', $slots->first()['start_time']);
        $this->assertSame('14:00:00', $slots->first()['shift_end_time']);
        $this->assertFalse($slots->contains('start_time', '08:00:00'));
    }
}
