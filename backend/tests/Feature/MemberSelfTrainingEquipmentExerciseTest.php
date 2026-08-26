<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\SelfTrainingProgram;
use App\Models\SelfTrainingSession;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemberSelfTrainingEquipmentExerciseTest extends TestCase
{
    use DatabaseTransactions;

    private User $memberUser;

    private SelfTrainingProgram $program;

    private SelfTrainingSession $session;

    protected function setUp(): void
    {
        parent::setUp();

        $role = Role::firstOrCreate(['name' => 'member']);
        $this->memberUser = User::create([
            'role_id' => $role->id,
            'name' => 'Self Equipment Member',
            'email' => uniqid('self_equipment_member_', true).'@example.test',
            'password' => 'password',
            'status' => 'active',
        ]);
        $member = MemberProfile::create([
            'user_id' => $this->memberUser->id,
            'member_code' => uniqid('SELF-EQ-'),
            'fitness_goal' => 'Strength',
        ]);
        $this->program = SelfTrainingProgram::create([
            'member_profile_id' => $member->id,
            'title' => 'Self Equipment Program',
            'status' => 'active',
        ]);
        $this->session = SelfTrainingSession::create([
            'self_training_program_id' => $this->program->id,
            'sequence_order' => 1,
            'title' => 'Cable Session',
            'status' => 'active',
        ]);
    }

    public function test_equipment_movement_is_canonical_and_survives_reload_edit_and_toggle(): void
    {
        $equipment = $this->equipment('Cable Station');
        $movement = $equipment->movements()->create([
            'movement_name' => 'Cable Chest Fly',
            'target_area' => 'Chest',
            'sort_order' => 1,
        ]);

        Sanctum::actingAs($this->memberUser, [], 'sanctum');
        $created = $this->postJson($this->exercisePath(), [
            'name' => 'Forged Name',
            'target_muscle' => 'Forged Target',
            'sets' => 3,
            'reps' => 10,
            'equipment_id' => $equipment->id,
            'gym_equipment_movement_id' => $movement->id,
        ])->assertCreated()
            ->assertJsonPath('data.name', 'Cable Chest Fly')
            ->assertJsonPath('data.target_muscle', 'Chest')
            ->assertJsonPath('data.equipment_id', $equipment->id)
            ->assertJsonPath('data.equipment_name', 'Cable Station')
            ->assertJsonPath('data.gym_equipment_movement_id', $movement->id)
            ->assertJsonPath('data.source', 'equipment_database');

        $exerciseId = $created->json('data.id');
        $this->getJson("/api/v1/member/self-training/{$this->program->id}")
            ->assertOk()
            ->assertJsonPath('data.sessions.0.exercises.0.equipment_name', 'Cable Station');

        $this->putJson($this->exercisePath()."/{$exerciseId}", [
            'name' => 'Cable Chest Fly',
            'target_muscle' => 'Chest',
            'sets' => 4,
            'reps' => 12,
            'equipment_id' => $equipment->id,
            'gym_equipment_movement_id' => $movement->id,
        ])->assertOk()
            ->assertJsonPath('data.sets', 4)
            ->assertJsonPath('data.equipment_name', 'Cable Station');

        $this->postJson($this->exercisePath()."/{$exerciseId}/toggle")
            ->assertOk()
            ->assertJsonPath('data.is_completed', true)
            ->assertJsonPath('data.equipment_name', 'Cable Station');
    }

    public function test_cross_equipment_movement_is_rejected_and_manual_remains_valid(): void
    {
        $cable = $this->equipment('Cable Station');
        $press = $this->equipment('Press Machine');
        $movement = $cable->movements()->create([
            'movement_name' => 'Cable Fly',
            'target_area' => 'Chest',
            'sort_order' => 1,
        ]);

        Sanctum::actingAs($this->memberUser, [], 'sanctum');
        $this->postJson($this->exercisePath(), [
            'name' => 'Cable Fly',
            'target_muscle' => 'Chest',
            'sets' => 3,
            'reps' => 10,
            'equipment_id' => $press->id,
            'gym_equipment_movement_id' => $movement->id,
        ])->assertUnprocessable();

        $this->postJson($this->exercisePath(), [
            'name' => 'Bodyweight Squat',
            'target_muscle' => 'Legs',
            'sets' => 3,
            'reps' => 10,
        ])->assertCreated()
            ->assertJsonPath('data.equipment_id', null)
            ->assertJsonPath('data.equipment_name', null)
            ->assertJsonPath('data.gym_equipment_movement_id', null)
            ->assertJsonPath('data.source', 'manual');
    }

    private function exercisePath(): string
    {
        return "/api/v1/member/self-training/{$this->program->id}/sessions/{$this->session->id}/exercises";
    }

    private function equipment(string $name): Equipment
    {
        return Equipment::create([
            'code' => 'EQ-'.strtoupper(substr(md5($name), 0, 5)),
            'name' => $name,
            'slug' => str($name)->slug().'-'.uniqid(),
            'category' => 'Machine',
            'description' => 'Self training equipment fixture.',
            'status' => 'available',
            'focus' => 'Strength',
            'is_active' => true,
        ]);
    }
}
