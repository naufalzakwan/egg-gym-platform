<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminSidebarBrandLayoutTest extends TestCase
{
    use DatabaseTransactions;

    public function test_shared_admin_sidebar_uses_compact_horizontal_brand_layout(): void
    {
        $layoutSource = file_get_contents(resource_path('views/admin/layouts/app.blade.php'));
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Sidebar Brand Admin',
            'email' => uniqid('sidebar_brand_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('class="brand"', false)
            ->assertSee('class="brand__text"', false)
            ->assertSeeText('MANAGEMENT')
            ->assertSee('.brand {', false)
            ->assertSee('display: flex;', false)
            ->assertSee('align-items: center;', false)
            ->assertSee('gap: 11px;', false)
            ->assertSee('width: 48px; height: 48px;', false)
            ->assertSee('margin-bottom: 20px;', false)
            ->assertDontSee('margin-bottom: 9px;', false);

        $this->assertStringContainsString('class="brand__logo"', $layoutSource);
        $this->assertStringContainsString('@if($appBranding[\'logo_path\'])', $layoutSource);
        $this->assertStringContainsString('asset(\'storage/\'.$appBranding[\'logo_path\'])', $layoutSource);
    }
}
