<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerClientEligibilityTest extends TestCase
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
            'name' => 'Trainer Client Eligibility',
            'email' => uniqid('trainer_client_eligibility_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $this->trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'price_per_session' => 150000,
        ]);
    }

    public function test_client_list_excludes_unverified_booking_states_and_includes_valid_engagements(): void
    {
        $excludedStatuses = [
            'pending',
            'waiting_payment',
            'payment_uploaded',
            'payment_rejected',
            'expired',
            'cancelled',
            'rejected',
        ];

        foreach ($excludedStatuses as $status) {
            $member = $this->createMember('Excluded '.str_replace('_', ' ', $status));
            $this->createBooking($member, $status);
        }

        $verified = $this->createMember('Verified Client');
        $this->createBooking($verified, 'payment_verified', now());

        $unpaidConfirmed = $this->createMember('Unpaid Confirmed');
        $this->createBooking($unpaidConfirmed, 'confirmed');

        $paidConfirmed = $this->createMember('Paid Confirmed Client');
        $this->createBooking($paidConfirmed, 'confirmed', now());

        $unpaidRescheduled = $this->createMember('Unpaid Rescheduled');
        $this->createBooking($unpaidRescheduled, 'rescheduled');

        $paidRescheduled = $this->createMember('Paid Rescheduled Client');
        $this->createBooking($paidRescheduled, 'rescheduled', now());

        $programOnly = $this->createMember('Program Client');
        $activeProgram = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $programOnly->id,
            'title' => 'Program Active Client',
            'status' => 'active',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $activeProgram->id,
            'sequence_order' => 1,
            'title' => 'Active Session',
            'status' => 'active',
        ]);

        $completedBooking = $this->createMember('Completed Booking Client');
        $this->createBooking($completedBooking, 'completed', now());

        $completedProgramMember = $this->createMember('Completed Program Client');
        $completedProgram = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $completedProgramMember->id,
            'title' => 'Stale Active Program',
            'status' => 'active',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $completedProgram->id,
            'sequence_order' => 1,
            'title' => 'Completed Session',
            'status' => 'completed',
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $response = $this->getJson('/api/v1/trainer/clients')->assertOk();
        $names = collect($response->json('data'))->pluck('name')->all();

        $this->assertEqualsCanonicalizing([
            'Paid Confirmed Client',
            'Paid Rescheduled Client',
            'Program Client',
            'Verified Client',
        ], $names);
        $this->assertNotContains('Unpaid Rescheduled', $names);
        $this->assertNotContains('Unpaid Confirmed', $names);
        $this->assertNotContains('Completed Booking Client', $names);
        $this->assertNotContains('Completed Program Client', $names);
        foreach ($excludedStatuses as $status) {
            $this->assertNotContains('Excluded '.str_replace('_', ' ', $status), $names);
        }
    }

    public function test_client_detail_uses_the_same_eligibility_scope_as_list(): void
    {
        $pending = $this->createMember('Pending Detail');
        $this->createBooking($pending, 'pending');

        $verified = $this->createMember('Verified Detail');
        $this->createBooking($verified, 'payment_verified', now());

        $programOnly = $this->createMember('Program Detail');
        $draftProgram = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $programOnly->id,
            'title' => 'Draft Program',
            'status' => 'draft',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $draftProgram->id,
            'sequence_order' => 1,
            'title' => 'Draft Session',
            'status' => 'draft',
        ]);

        $completedProgramMember = $this->createMember('Completed Program Detail');
        $completedProgram = TrainingProgram::create([
            'trainer_profile_id' => $this->trainer->id,
            'member_profile_id' => $completedProgramMember->id,
            'title' => 'Completed Program Detail',
            'status' => 'active',
        ]);
        TrainingProgramSession::create([
            'training_program_id' => $completedProgram->id,
            'sequence_order' => 1,
            'title' => 'Done',
            'status' => 'completed',
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->getJson("/api/v1/trainer/clients/{$pending->id}")->assertNotFound();
        $this->getJson("/api/v1/trainer/clients/{$verified->id}")
            ->assertOk()
            ->assertJsonPath('data.name', 'Verified Detail')
            ->assertJsonPath('data.summary.pending_sessions', 0);
        $this->getJson("/api/v1/trainer/clients/{$programOnly->id}")
            ->assertOk()
            ->assertJsonPath('data.name', 'Program Detail')
            ->assertJsonPath('data.active_program.title', 'Draft Program');
        $this->getJson("/api/v1/trainer/clients/{$completedProgramMember->id}")
            ->assertNotFound();
    }

    private function createMember(string $name): MemberProfile
    {
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $memberRole->id,
            'name' => $name,
            'email' => uniqid('client_eligibility_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => uniqid('CLIENT-'),
            'fitness_goal' => 'General fitness',
        ]);
    }

    private function createBooking(
        MemberProfile $member,
        string $status,
        $paymentVerifiedAt = null
    ): Booking {
        return Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $this->trainer->id,
            'session_title' => 'Eligibility '.$status,
            'session_date' => now()->addDay()->toDateString(),
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Egg Gym',
            'status' => $status,
            'payment_verified_at' => $paymentVerifiedAt,
        ]);
    }
}
