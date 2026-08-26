<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerScheduleVisibilityTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainerProfile $trainer;

    protected function setUp(): void
    {
        parent::setUp();

        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Schedule Visibility Trainer',
            'email' => uniqid('schedule_visibility_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'rating' => 5,
        ]);
    }

    public function test_guest_sees_false_for_active_trainer_without_weekly_schedule(): void
    {
        $this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->assertJsonPath($this->trainerPath('has_active_schedule'), false);
    }

    public function test_guest_sees_true_when_trainer_has_a_persisted_weekly_shift(): void
    {
        $this->createWeeklyShift();

        $this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->assertJsonPath($this->trainerPath('has_active_schedule'), true);
    }

    public function test_generated_closed_concrete_schedule_does_not_count(): void
    {
        TrainerScheduleDate::create([
            'trainer_profile_id' => $this->trainer->id,
            'schedule_date' => now()->addDay()->toDateString(),
            'state' => 'closed',
            'source' => 'generated',
            'template_version' => 1,
            'generated_at' => now(),
        ]);

        $this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->assertJsonPath($this->trainerPath('has_active_schedule'), false);
    }

    public function test_invalid_weekly_shift_does_not_count_as_active_schedule(): void
    {
        $this->trainer->schedules()->create([
            'day_of_week' => 1,
            'start_time' => '12:00:00',
            'end_time' => '08:00:00',
            'session_duration_minutes' => 0,
        ]);

        $this->getJson('/api/v1/public/trainers')
            ->assertOk()
            ->assertJsonPath($this->trainerPath('has_active_schedule'), false);
    }

    public function test_full_trainer_with_bookings_still_has_active_schedule(): void
    {
        $this->createWeeklyShift();
        $balancingUser = User::create([
            'role_id' => $this->trainerUser->role_id,
            'name' => 'Schedule Visibility Balancing Trainer',
            'email' => uniqid('schedule_visibility_balancing_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        TrainerProfile::create([
            'user_id' => $balancingUser->id,
            'specialty' => 'Strength',
            'rating' => 5,
        ]);
        $quotaCap = $this->trainer->currentQuotaCap();

        foreach (range(1, $quotaCap) as $sequence) {
            $memberUser = User::create([
                'name' => "Visibility Member {$sequence}",
                'email' => uniqid("visibility_member_{$sequence}_", true).'@example.test',
                'password' => 'password',
                'status' => 'active',
            ]);
            $member = MemberProfile::create([
                'user_id' => $memberUser->id,
                'member_code' => uniqid("VIS-{$sequence}-"),
            ]);
            Booking::create([
                'member_profile_id' => $member->id,
                'trainer_profile_id' => $this->trainer->id,
                'session_title' => 'Booked session',
                'session_date' => now()->addWeek()->toDateString(),
                'start_time' => '08:00:00',
                'end_time' => '09:00:00',
                'session_duration_minutes' => 60,
                'location' => 'Studio A',
                'status' => 'confirmed',
            ]);
        }

        $response = $this->getJson('/api/v1/public/trainers')->assertOk();

        $response->assertJsonPath($this->trainerPath('is_available'), false)
            ->assertJsonPath($this->trainerPath('has_active_schedule'), true);
    }

    public function test_trainer_dashboard_exposes_the_same_schedule_flag(): void
    {
        Sanctum::actingAs($this->trainerUser, [], 'sanctum');

        $this->getJson('/api/v1/trainer/dashboard')
            ->assertOk()
            ->assertJsonPath('data.has_active_schedule', false);

        $this->createWeeklyShift();

        $this->getJson('/api/v1/trainer/dashboard')
            ->assertOk()
            ->assertJsonPath('data.has_active_schedule', true);
    }

    private function createWeeklyShift(): void
    {
        $this->trainer->schedules()->create([
            'day_of_week' => 1,
            'start_time' => '08:00:00',
            'end_time' => '12:00:00',
            'session_duration_minutes' => 240,
        ]);
    }

    private function trainerPath(string $field): string
    {
        $index = collect($this->getJson('/api/v1/public/trainers')->json('data'))
            ->search(fn (array $trainer) => $trainer['id'] === $this->trainer->id);

        $this->assertNotFalse($index);

        return "data.{$index}.{$field}";
    }
}
