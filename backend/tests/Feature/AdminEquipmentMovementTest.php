<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminEquipmentMovementTest extends TestCase
{
    use DatabaseTransactions;

    public function test_create_ui_and_store_use_repeatable_movement_pairs_in_input_order(): void
    {
        $admin = $this->createAdmin();

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.create'))
            ->assertOk()
            ->assertSeeText('Gerakan yang Bisa Dilakukan')
            ->assertSeeText('Nama Gerakan')
            ->assertSeeText('Bagian Otot / Target')
            ->assertSeeText('+ Tambah Gerakan')
            ->assertSee('name="movements[0][movement_name]"', false)
            ->assertSee('name="movements[0][target_area]"', false)
            ->assertSee('data-movement-add', false)
            ->assertSee('data-movement-remove', false);

        $this->withSession(['admin_user_id' => $admin->id])
            ->post(route('admin.equipments.store'), $this->payload([
                ['movement_name' => '  Cable Fly  ', 'target_area' => '  Chest '],
                ['movement_name' => '', 'target_area' => ''],
                ['movement_name' => 'Triceps Pushdown', 'target_area' => 'Triceps'],
            ]))
            ->assertRedirect(route('admin.equipments.index'));

        $equipment = Equipment::query()->where('slug', 'movement-cable-station')->firstOrFail();
        $this->assertSame([
            ['Cable Fly', 'Chest', 1],
            ['Triceps Pushdown', 'Triceps', 2],
        ], $equipment->movements->map(fn ($movement) => [
            $movement->movement_name,
            $movement->target_area,
            $movement->sort_order,
        ])->all());
    }

    public function test_partial_movement_row_is_rejected_but_empty_rows_are_allowed(): void
    {
        $admin = $this->createAdmin();

        $this->withSession(['admin_user_id' => $admin->id])
            ->from(route('admin.equipments.create'))
            ->post(route('admin.equipments.store'), $this->payload([
                ['movement_name' => 'Cable Fly', 'target_area' => ''],
            ]))
            ->assertRedirect(route('admin.equipments.create'))
            ->assertSessionHasErrors('movements.0.target_area');

        $this->withSession(['admin_user_id' => $admin->id])
            ->post(route('admin.equipments.store'), $this->payload([
                ['movement_name' => '', 'target_area' => ''],
            ], 'empty-movement-equipment'))
            ->assertRedirect(route('admin.equipments.index'));

        $equipment = Equipment::query()->where('slug', 'empty-movement-equipment')->firstOrFail();
        $this->assertCount(0, $equipment->movements);
    }

    public function test_edit_prefills_and_resyncs_movement_pairs(): void
    {
        $admin = $this->createAdmin();
        $equipment = $this->createEquipment('Edit Movement Machine');
        $equipment->movements()->createMany([
            ['movement_name' => 'Bench Press', 'target_area' => 'Chest', 'sort_order' => 1],
            ['movement_name' => 'Incline Press', 'target_area' => 'Upper Chest', 'sort_order' => 2],
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.edit', $equipment))
            ->assertOk()
            ->assertSee('value="Bench Press"', false)
            ->assertSee('value="Chest"', false)
            ->assertSee('value="Incline Press"', false)
            ->assertSee('value="Upper Chest"', false);

        $this->withSession(['admin_user_id' => $admin->id])
            ->put(route('admin.equipments.update', $equipment), $this->payload([
                ['movement_name' => 'Shoulder Press', 'target_area' => 'Shoulder'],
                ['movement_name' => 'Bench Press', 'target_area' => 'Chest'],
            ], $equipment->slug, $equipment->name))
            ->assertRedirect(route('admin.equipments.index'));

        $this->assertSame([
            ['Shoulder Press', 'Shoulder', 1],
            ['Bench Press', 'Chest', 2],
        ], $equipment->refresh()->movements->map(fn ($movement) => [
            $movement->movement_name,
            $movement->target_area,
            $movement->sort_order,
        ])->all());
    }

    public function test_public_equipment_list_and_detail_expose_ordered_movements(): void
    {
        $equipment = $this->createEquipment('Public Movement Machine');
        $equipment->update(['suggested_moves_json' => ['Legacy movement']]);
        $equipment->movements()->createMany([
            ['movement_name' => 'Lat Pulldown', 'target_area' => 'Back', 'sort_order' => 2],
            ['movement_name' => 'Cable Fly', 'target_area' => 'Chest', 'sort_order' => 1],
        ]);

        $list = $this->getJson('/api/v1/public/equipment')->assertOk();
        $item = collect($list->json('data'))->firstWhere('id', $equipment->id);
        $this->assertSame(['Legacy movement'], $item['suggested_movements']);
        $this->assertSame(['Cable Fly', 'Lat Pulldown'], collect($item['movements'])->pluck('movement_name')->all());
        $this->assertSame(['Chest', 'Back'], collect($item['movements'])->pluck('target_area')->all());

        $this->getJson("/api/v1/public/equipment/{$equipment->id}")
            ->assertOk()
            ->assertJsonPath('data.movements.0.movement_name', 'Cable Fly')
            ->assertJsonPath('data.movements.0.target_area', 'Chest')
            ->assertJsonPath('data.movements.1.movement_name', 'Lat Pulldown')
            ->assertJsonPath('data.movements.1.target_area', 'Back');
    }

    private function payload(
        array $movements,
        string $slug = 'movement-cable-station',
        string $name = 'Movement Cable Station'
    ): array {
        return [
            'name' => $name,
            'slug' => $slug,
            'category' => 'Functional',
            'description' => 'Equipment movement test fixture.',
            'status' => 'available',
            'focus' => 'Full Body',
            'difficulty' => 'All Levels',
            'movements' => $movements,
            'is_active' => '1',
        ];
    }

    private function createAdmin(): User
    {
        $role = Role::firstOrCreate(['name' => 'admin']);

        return User::create([
            'role_id' => $role->id,
            'name' => 'Equipment Movement Admin',
            'email' => uniqid('equipment_movement_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function createEquipment(string $name): Equipment
    {
        return Equipment::create([
            'code' => 'EQ-'.strtoupper(substr(md5($name), 0, 5)),
            'name' => $name,
            'slug' => str($name)->slug().'-'.uniqid(),
            'category' => 'Machine',
            'description' => 'Equipment movement fixture.',
            'status' => 'available',
            'focus' => 'Strength',
            'is_active' => true,
        ]);
    }
}
