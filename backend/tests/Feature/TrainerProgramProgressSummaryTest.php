<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerProgramProgressSummaryTest extends TestCase
{
    use DatabaseTransactions;

    public function test_program_list_summary_matches_completed_session_statuses(): void
    {
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);

        $trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Progress Summary Trainer',
            'email' => uniqid('progress_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'Progress testing',
        ]);

        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Progress Summary Member',
            'email' => uniqid('progress_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('PROGRESS-'),
        ]);

        $program = TrainingProgram::create([
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'title' => 'Four Session Program',
            'status' => 'active',
        ]);

        foreach (range(1, 4) as $sequence) {
            TrainingProgramSession::create([
                'training_program_id' => $program->id,
                'sequence_order' => $sequence,
                'title' => 'Session '.$sequence,
                'duration_minutes' => 60,
                'status' => 'completed',
            ]);
        }

        Sanctum::actingAs($trainerUser, [], 'sanctum');

        $this->getJson('/api/v1/trainer/programs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.sessions_count', 4)
            ->assertJsonPath('data.0.completed_sessions_count', 4)
            ->assertJsonPath('data.0.progress_percent', 100);

        $this->getJson('/api/v1/trainer/programs/'.$program->id)
            ->assertOk()
            ->assertJsonPath('data.summary.total_sessions', 4)
            ->assertJsonCount(4, 'data.sessions')
            ->assertJsonPath('data.sessions.0.status', 'completed')
            ->assertJsonPath('data.sessions.3.status', 'completed');
    }
}
