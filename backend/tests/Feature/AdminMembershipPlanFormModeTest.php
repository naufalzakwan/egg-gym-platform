<?php

namespace Tests\Feature;

use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminMembershipPlanFormModeTest extends TestCase
{
    use DatabaseTransactions;

    public function test_membership_plan_page_starts_hidden_and_has_explicit_create_edit_modes(): void
    {
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Package Mode Test Admin',
            'email' => uniqid('package_mode_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $plan = MembershipPlan::create([
            'name' => 'Editable Mode Package',
            'slug' => uniqid('editable-mode-'),
            'description' => 'Package mode test',
            'price' => 375000,
            'duration_days' => 90,
            'billing_period' => 'monthly',
            'features_json' => ['Benefit real satu', 'Benefit real dua'],
            'is_active' => true,
        ]);

        $this->withSession([
            'admin_user_id' => $admin->id,
            'success' => 'Paket membership berhasil diperbarui.',
        ])
            ->get(route('admin.membership-plans.index'))
            ->assertOk()
            ->assertSee('id="pkgConfigForm" method="POST"', false)
            ->assertSee('hidden>', false)
            ->assertSee('data-plan-id="'.$plan->id.'"', false)
            ->assertDontSee('data-plan-id="'.$plan->id.'" role="button"', false)
            ->assertSee('class="pkg-action-edit" title="Edit paket '.$plan->name.'"', false)
            ->assertSee('onclick="pkgEditPackage('.$plan->id.')"', false)
            ->assertSee('.pkg-edit-slot { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }', false)
            ->assertSee('.pkg-config { grid-column: 1 / span 2;', false)
            ->assertSee('if (String(pkgSelectedPlanId) === String(id) && !form.hidden)', false)
            ->assertSee('pkgCloseEditPanel();', false)
            ->assertSee("methodInput.value = 'PUT';", false)
            ->assertSee('form.hidden = false;', false)
            ->assertSee("document.getElementById('pkgConfigForm').hidden = true;", false)
            ->assertSeeText('Edit Paket Membership')
            ->assertSeeText('Tambah Paket Baru')
            ->assertSee('id="pkgCreateModal" role="dialog"', false)
            ->assertSee('id="pkgCreateForm" method="POST"', false)
            ->assertSee("document.getElementById('pkgCreateModal').hidden = false;", false)
            ->assertSeeText('Simpan Paket')
            ->assertSee('data-auto-dismiss="4000"', false)
            ->assertSee("flash.classList.add('is-dismissing');", false)
            ->assertSee('grid-template-columns: repeat(auto-fit, minmax(170px, 1fr))', false)
            ->assertSee("const item = document.createElement('button');", false)
            ->assertSee("item.setAttribute('aria-pressed', b.checked ? 'true' : 'false');", false)
            ->assertSee('event.preventDefault(); pkgAddBenefit();', false)
            ->assertSee("remove.className = 'pkg-benefit-remove';", false)
            ->assertSeeText('Paket lain tidak ikut diubah.')
            ->assertSeeText('Akses gym')
            ->assertSee('toggle.disabled = scheduled;', false)
            ->assertSee("hidden.value = '1';", false)
            ->assertSeeText('Benefit custom')
            ->assertDontSeeText('Paket tersedia untuk member')
            ->assertDontSeeText('Real-Time Preview')
            ->assertDontSeeText('IDR 0')
            ->assertDontSee('id="pkgSelect"', false);
    }
}
