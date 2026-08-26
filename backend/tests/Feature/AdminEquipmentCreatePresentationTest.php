<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\Role;
use App\Models\User;
use App\Support\EquipmentTaxonomy;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminEquipmentCreatePresentationTest extends TestCase
{
    use DatabaseTransactions;

    public function test_create_page_is_compact_sectioned_and_preserves_existing_payload_names(): void
    {
        $admin = $this->createAdmin();

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.create'));

        $response->assertOk()
            ->assertViewIs('admin.equipments.create')
            ->assertSeeText('Tambah Alat')
            ->assertSeeText('Alat Gym / Tambah Alat')
            ->assertSeeText('Informasi Dasar')
            ->assertSeeText('Deskripsi Alat')
            ->assertSeeText('Foto Alat')
            ->assertSeeText('Panduan Penggunaan')
            ->assertSeeText('Pengaturan')
            ->assertSee('width: min(100%, 1180px)', false)
            ->assertSee('grid-template-columns: repeat(2, minmax(0, 1fr))', false)
            ->assertSee('min-height: 110px', false)
            ->assertSee('min-height: 88px', false)
            ->assertSee('enctype="multipart/form-data"', false)
            ->assertSee('name="image"', false)
            ->assertSee('accept="image/png,image/jpeg,image/webp"', false)
            ->assertSee('data-change-photo', false)
            ->assertSee('data-remove-photo', false)
            ->assertSee('URL.createObjectURL(file)', false)
            ->assertSee('name="is_active" value="0"', false)
            ->assertSee('name="is_active" value="1"', false)
            ->assertSee("button.disabled = true; button.textContent = 'Menyimpan Alat...'", false);
        $response->assertSeeText('Simpan Alat')
            ->assertSee('class="eq-card__icon"', false)
            ->assertSee('grid-template-areas: "benefits flow" "safety safety"', false)
            ->assertDontSee('data-list-name="suggested_moves_text"', false)
            ->assertSee('aspect-ratio: 16/9', false)
            ->assertSee('data-file-name', false)
            ->assertSee('data-file-size', false)
            ->assertSee('data-description-count', false)
            ->assertSee('position: sticky', false)
            ->assertSee('.eq-list__remove::before', false)
            ->assertSeeText('Klik untuk memilih foto')
            ->assertDontSeeText('Simpan Equipment');
        $response->assertSee('name="category_selection"', false)
            ->assertSee('name="difficulty_selection"', false)
            ->assertSeeText('Free Weight')
            ->assertSeeText('All Levels')
            ->assertSeeText('Lainnya')
            ->assertSee('name="category_custom"', false)
            ->assertSee('name="difficulty_custom"', false)
            ->assertSee('data-taxonomy-value', false);
        $response->assertSeeText('Nama Alat')
            ->assertSeeText('Fokus Latihan')
            ->assertSeeText('Tingkat Kesulitan')
            ->assertSeeText('Label Tahap')
            ->assertSeeText('Durasi/Waktu Penggunaan')
            ->assertSeeText('Cocok Untuk')
            ->assertSeeText('Deskripsi Alat')
            ->assertSeeText('Manfaat Utama')
            ->assertSeeText('Langkah Penggunaan')
            ->assertSeeText('Panduan Keamanan')
            ->assertDontSeeText('Gerakan yang Disarankan')
            ->assertDontSeeText('Tambahkan gerakan latihan yang cocok untuk alat ini.')
            ->assertSeeText('Gerakan yang Bisa Dilakukan')
            ->assertSeeText('Alat Aktif')
            ->assertSeeText('+ Tambah Manfaat')
            ->assertSeeText('+ Tambah Langkah')
            ->assertSeeText('+ Tambah Catatan')
            ->assertSeeText('+ Tambah Gerakan')
            ->assertSee('data-dynamic-list', false)
            ->assertSee('name="key_benefits_text" data-list-payload hidden', false)
            ->assertSee(".filter(Boolean).join('\\n')", false)
            ->assertSee("if (!rows.querySelector('[data-list-row]')) addRow()", false);

        foreach ([
            'name', 'slug', 'category', 'focus', 'status', 'stage_label', 'usage_window',
            'best_for', 'difficulty', 'description', 'key_benefits_text', 'usage_flow_text',
            'safety_notes_text',
        ] as $field) {
            $response->assertSee('name="'.$field.'"', false);
        }
    }

    public function test_store_still_uploads_real_image_and_parses_one_item_per_line(): void
    {
        Storage::fake('public');
        $admin = $this->createAdmin();

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->post(route('admin.equipments.store'), [
                'name' => 'Compact Cable Machine',
                'slug' => '',
                'category' => 'Strength',
                'description' => 'Mesin kabel compact untuk latihan seluruh tubuh.',
                'status' => 'available',
                'focus' => 'Full Body',
                'stage_label' => 'Strength Zone',
                'usage_window' => '10-20 menit',
                'best_for' => 'Member intermediate',
                'difficulty' => 'Intermediate',
                'key_benefits_text' => "Stabilitas\nKekuatan",
                'usage_flow_text' => "Atur pin\nPilih beban",
                'safety_notes_text' => "Kunci pin\nJaga postur",
                'suggested_moves_text' => "Cable row\nTriceps pushdown",
                'is_active' => '1',
                'image' => UploadedFile::fake()->image('cable.webp', 800, 600)->size(900),
            ]);

        $response->assertRedirect(route('admin.equipments.index'));
        $equipment = Equipment::query()->where('name', 'Compact Cable Machine')->firstOrFail();
        $this->assertSame('compact-cable-machine', $equipment->slug);
        $this->assertSame(['Stabilitas', 'Kekuatan'], $equipment->key_benefits_json);
        $this->assertSame(['Atur pin', 'Pilih beban'], $equipment->usage_flow_json);
        $this->assertSame(['Kunci pin', 'Jaga postur'], $equipment->safety_notes_json);
        $this->assertSame(['Cable row', 'Triceps pushdown'], $equipment->suggested_moves_json);
        $this->assertTrue($equipment->is_active);
        $this->assertStringStartsWith('equipments/', $equipment->image_path);
        Storage::disk('public')->assertExists($equipment->image_path);
    }

    public function test_custom_taxonomy_values_are_required_and_stored_without_changing_database_fields(): void
    {
        $admin = $this->createAdmin();
        $base = [
            'name' => 'Custom Taxonomy Equipment',
            'slug' => 'custom-taxonomy-equipment',
            'description' => 'Equipment dengan taxonomy custom.',
            'focus' => 'Custom focus',
            'status' => 'available',
            'category' => '',
            'category_selection' => '__other__',
            'difficulty' => '',
            'difficulty_selection' => '__other__',
            'is_active' => '1',
        ];

        $this->withSession(['admin_user_id' => $admin->id])
            ->from(route('admin.equipments.create'))
            ->post(route('admin.equipments.store'), $base)
            ->assertRedirect(route('admin.equipments.create'))
            ->assertSessionHasErrors(['category_custom', 'difficulty_custom']);

        $this->withSession(['admin_user_id' => $admin->id])
            ->post(route('admin.equipments.store'), $base + [
                'category_custom' => 'Aquatic Training',
                'difficulty_custom' => 'Coach Assisted',
            ])
            ->assertRedirect(route('admin.equipments.index'));

        $equipment = Equipment::query()->where('slug', 'custom-taxonomy-equipment')->firstOrFail();
        $this->assertSame('Aquatic Training', $equipment->category);
        $this->assertSame('Coach Assisted', $equipment->difficulty);
    }

    public function test_edit_legacy_taxonomy_uses_other_mode_and_preserves_old_values(): void
    {
        $admin = $this->createAdmin();
        $equipment = Equipment::create([
            'code' => 'EQ-LGCY',
            'name' => 'Legacy Taxonomy Equipment',
            'slug' => 'legacy-taxonomy-'.uniqid(),
            'category' => 'Legacy Conditioning',
            'description' => 'Legacy equipment description.',
            'status' => 'available',
            'focus' => 'Conditioning',
            'difficulty' => 'Intermediate Friendly',
            'key_benefits_json' => ['Legacy Benefit One', 'Legacy Benefit Two'],
            'usage_flow_json' => ['Legacy Step One', 'Legacy Step Two'],
            'safety_notes_json' => ['Legacy Safety'],
            'suggested_moves_json' => ['Legacy Move'],
            'is_active' => true,
        ]);

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.edit', $equipment));

        $response->assertOk()
            ->assertViewIs('admin.equipments.form')
            ->assertSee('name="category_selection"', false)
            ->assertSee('value="__other__" selected', false)
            ->assertSee('name="category_custom" value="Legacy Conditioning"', false)
            ->assertSee('name="difficulty_custom" value="Intermediate Friendly"', false)
            ->assertSee('value="Legacy Benefit One"', false)
            ->assertSee('value="Legacy Benefit Two"', false)
            ->assertSee('value="Legacy Step One"', false)
            ->assertSee('name="key_benefits_text" data-list-payload hidden', false)
            ->assertDontSeeText('Gerakan yang Disarankan')
            ->assertDontSee('name="suggested_moves_text"', false)
            ->assertSeeText('Gerakan yang Bisa Dilakukan')
            ->assertDontSeeText('Key Benefits')
            ->assertDontSeeText('Usage Flow')
            ->assertSee("input.addEventListener('input', syncTaxonomyField)", false);

        $this->withSession(['admin_user_id' => $admin->id])
            ->put(route('admin.equipments.update', $equipment), [
                'name' => $equipment->name,
                'slug' => $equipment->slug,
                'category' => 'Legacy Conditioning',
                'category_selection' => '__other__',
                'category_custom' => 'Legacy Conditioning',
                'description' => $equipment->description,
                'status' => 'available',
                'focus' => $equipment->focus,
                'difficulty' => 'Intermediate Friendly',
                'difficulty_selection' => '__other__',
                'difficulty_custom' => 'Intermediate Friendly',
                'key_benefits_text' => "Legacy Benefit One\nLegacy Benefit Two",
                'usage_flow_text' => "Legacy Step One\nLegacy Step Two",
                'safety_notes_text' => 'Legacy Safety',
                'suggested_moves_text' => 'Legacy Move',
                'is_active' => '1',
            ])
            ->assertRedirect(route('admin.equipments.index'));

        $equipment->refresh();
        $this->assertSame('Legacy Conditioning', $equipment->category);
        $this->assertSame('Intermediate Friendly', $equipment->difficulty);
        $this->assertSame(['Legacy Benefit One', 'Legacy Benefit Two'], $equipment->key_benefits_json);
        $this->assertSame(['Legacy Move'], $equipment->suggested_moves_json);
    }

    public function test_index_category_filters_share_taxonomy_and_group_custom_values_as_other(): void
    {
        $admin = $this->createAdmin();
        $canonical = $this->createEquipment('Canonical Machine', 'Machine');
        $custom = $this->createEquipment('Custom Aquatic Rig', 'Aquatic Training');

        $index = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.index'));
        $index->assertOk()
            ->assertViewHas('categories', EquipmentTaxonomy::CATEGORIES)
            ->assertDontSeeText('Sistem Aktif')
            ->assertDontSee('eqToast', false)
            ->assertSeeText('Semua Alat')
            ->assertSeeText('Cardio')
            ->assertSeeText('Strength')
            ->assertSeeText('Functional')
            ->assertSeeText('Free Weight')
            ->assertSeeText('Machine')
            ->assertSeeText('Mobility')
            ->assertSeeText('Recovery')
            ->assertSeeText('Accessories')
            ->assertSeeText('Lainnya');

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.index', ['category' => 'Machine', 'search' => 'Canonical']))
            ->assertOk()
            ->assertViewHas('equipments', fn ($equipments) => $equipments->pluck('id')->all() === [$canonical->id])
            ->assertSeeText('Canonical Machine')
            ->assertDontSeeText('Custom Aquatic Rig');

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.index', ['category' => EquipmentTaxonomy::OTHER]))
            ->assertOk()
            ->assertViewHas('equipments', fn ($equipments) => $equipments->contains('id', $custom->id)
                && ! $equipments->contains('id', $canonical->id))
            ->assertSeeText('Custom Aquatic Rig')
            ->assertDontSeeText('Canonical Machine');

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.equipments.index', ['category' => 'Recovery', 'search' => 'does-not-exist']))
            ->assertOk()
            ->assertSeeText('Belum ada alat pada kategori ini.');
    }

    private function createAdmin(): User
    {
        $role = Role::firstOrCreate(['name' => 'admin']);

        return User::create([
            'role_id' => $role->id,
            'name' => 'Equipment Create Admin',
            'email' => uniqid('equipment_create_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function createEquipment(string $name, string $category): Equipment
    {
        return Equipment::create([
            'code' => 'EQ-'.strtoupper(substr(md5($name), 0, 5)),
            'name' => $name,
            'slug' => str($name)->slug().'-'.uniqid(),
            'category' => $category,
            'description' => 'Equipment filter fixture.',
            'status' => 'available',
            'focus' => 'Filter focus',
            'is_active' => true,
        ]);
    }
}
