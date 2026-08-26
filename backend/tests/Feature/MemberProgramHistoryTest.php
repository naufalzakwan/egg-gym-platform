<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberProgramHistoryTest extends TestCase
{
    use DatabaseTransactions;

    public function test_completed_rated_program_exposes_real_history_metadata(): void
    {
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);

        $trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'History Trainer',
            'email' => uniqid('history_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $trainer = TrainerProfile::create([
            'user_id' => $trainerUser->id,
            'specialty' => 'History testing',
        ]);

        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'History Member',
            'email' => uniqid('history_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('HISTORY-'),
        ]);

        $program = TrainingProgram::create([
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'title' => 'Completed Rated Program',
            'status' => 'active',
            'ended_at' => '2026-07-20',
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

        $rating = TrainerRating::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'training_program_id' => $program->id,
            'rating' => 5,
            'testimonial' => 'Program selesai.',
        ]);
        $rating->forceFill([
            'created_at' => CarbonImmutable::parse('2026-07-21T17:28:26+07:00'),
            'updated_at' => CarbonImmutable::parse('2026-07-21T17:28:26+07:00'),
        ])->save();

        Sanctum::actingAs($memberUser, [], 'sanctum');

        $this->getJson('/api/v1/member/programs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $program->id)
            ->assertJsonPath('data.0.status', 'completed')
            ->assertJsonPath('data.0.progress_percent', 100)
            ->assertJsonPath('data.0.total_sessions', 4)
            ->assertJsonPath('data.0.completed_sessions', 4)
            ->assertJsonPath('data.0.program_completed', true)
            ->assertJsonPath('data.0.already_rated', true)
            ->assertJsonPath('data.0.can_rate', false)
            ->assertJsonPath('data.0.ended_at', '2026-07-20')
            ->assertJsonPath('data.0.rating', 5)
            ->assertJsonPath('data.0.rated_at', '2026-07-21T17:28:26+07:00');
    }
}
