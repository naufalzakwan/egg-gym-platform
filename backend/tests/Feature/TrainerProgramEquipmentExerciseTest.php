<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainingProgram;
use App\Models\TrainingProgramSession;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrainerProgramEquipmentExerciseTest extends TestCase
{
    use DatabaseTransactions;

    private User $trainerUser;

    private TrainingProgramSession $session;

    protected function setUp(): void
    {
        parent::setUp();

        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->trainerUser = User::create([
            'role_id' => $trainerRole->id,
            'name' => 'Equipment Exercise Trainer',
            'email' => uniqid('equipment_exercise_trainer_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $trainer = TrainerProfile::create([
            'user_id' => $this->trainerUser->id,
            'specialty' => 'Strength',
            'price_per_session' => 150000,
        ]);
        $memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Equipment Exercise Member',
            'email' => uniqid('equipment_exercise_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => uniqid('EQ-EX-'),
            'fitness_goal' => 'Strength',
        ]);
        $program = TrainingProgram::create([
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'title' => 'Equipment Exercise Program',
            'status' => 'active',
        ]);
        $this->session = TrainingProgramSession::create([
            'training_program_id' => $program->id,
            'sequence_order' => 1,
            'title' => 'Cable Session',
            'duration_minutes' => 60,
            'status' => 'active',
        ]);
    }

    public function test_equipment_movement_source_is_persisted_and_returned(): void
    {
        $equipment = $this->equipment('Cable Station');
        $movement = $equipment->movements()->create([
            'movement_name' => 'Cable Fly',
            'target_area' => 'Chest',
            'sort_order' => 1,
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $response = $this->postJson(
            "/api/v1/trainer/program-sessions/{$this->session->id}/exercises",
            [
                'sequence_order' => 1,
                'custom_name' => 'Forged Exercise Name',
                'custom_target_muscle' => 'Forged Target',
                'sets' => 3,
                'reps' => 12,
                'equipment_id' => $equipment->id,
                'equipment_name' => 'Forged Client Name',
                'gym_equipment_movement_id' => $movement->id,
            ]
        )->assertCreated()
            ->assertJsonPath('data.custom_name', 'Cable Fly')
            ->assertJsonPath('data.equipment_id', $equipment->id)
            ->assertJsonPath('data.equipment_name', 'Cable Station')
            ->assertJsonPath('data.gym_equipment_movement_id', $movement->id)
            ->assertJsonPath('data.source', 'equipment_database');

        $exerciseId = $response->json('data.id');
        $this->getJson("/api/v1/trainer/programs/{$this->session->training_program_id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.exercises.0.id', $exerciseId)
            ->assertJsonPath('data.sessions.0.exercises.0.equipment_name', 'Cable Station');

        $this->getJson("/api/v1/trainer/program-sessions/{$this->session->id}/progress")
            ->assertOk()
            ->assertJsonPath('data.exercises.0.id', $exerciseId)
            ->assertJsonPath('data.exercises.0.target_muscle', 'Chest')
            ->assertJsonPath('data.exercises.0.equipment_id', $equipment->id)
            ->assertJsonPath('data.exercises.0.equipment_name', 'Cable Station')
            ->assertJsonPath('data.exercises.0.gym_equipment_movement_id', $movement->id);

        $this->session->update(['member_ready' => true, 'member_ready_at' => now()]);
        $this->postJson(
            "/api/v1/trainer/program-sessions/{$this->session->id}/progress",
            ['exercise_id' => $exerciseId, 'completed_sets' => 1]
        )->assertOk()
            ->assertJsonPath('data.exercises.0.completed_sets', 1)
            ->assertJsonPath('data.exercises.0.equipment_name', 'Cable Station');
    }

    public function test_movement_must_belong_to_selected_equipment_and_manual_remains_valid(): void
    {
        $cable = $this->equipment('Cable Station');
        $press = $this->equipment('Press Machine');
        $movement = $cable->movements()->create([
            'movement_name' => 'Cable Fly',
            'target_area' => 'Chest',
            'sort_order' => 1,
        ]);

        Sanctum::actingAs($this->trainerUser, [], 'sanctum');
        $this->postJson(
            "/api/v1/trainer/program-sessions/{$this->session->id}/exercises",
            [
                'sequence_order' => 1,
                'custom_name' => 'Cable Fly',
                'custom_target_muscle' => 'Chest',
                'sets' => 3,
                'reps' => 12,
                'equipment_id' => $press->id,
                'gym_equipment_movement_id' => $movement->id,
            ]
        )->assertUnprocessable();

        $this->postJson(
            "/api/v1/trainer/program-sessions/{$this->session->id}/exercises",
            [
                'sequence_order' => 1,
                'custom_name' => 'Bodyweight Squat',
                'custom_target_muscle' => 'Legs',
                'sets' => 3,
                'reps' => 10,
            ]
        )->assertCreated()
            ->assertJsonPath('data.equipment_id', null)
            ->assertJsonPath('data.gym_equipment_movement_id', null)
            ->assertJsonPath('data.source', 'manual');
    }

    private function equipment(string $name): Equipment
    {
        return Equipment::create([
            'code' => 'EQ-'.strtoupper(substr(md5($name), 0, 5)),
            'name' => $name,
            'slug' => str($name)->slug().'-'.uniqid(),
            'category' => 'Machine',
            'description' => 'Equipment exercise fixture.',
            'status' => 'available',
            'focus' => 'Strength',
            'is_active' => true,
        ]);
    }
}
