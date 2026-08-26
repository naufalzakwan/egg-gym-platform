<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminMembershipPlanHeadingCleanupTest extends TestCase
{
    use DatabaseTransactions;

    public function test_membership_plan_page_removes_redundant_management_packages_heading(): void
    {
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Membership Heading Admin',
            'email' => uniqid('membership_heading_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.membership-plans.index'))
            ->assertOk()
            ->assertSeeText('Paket Membership')
            ->assertSeeText('+ TAMBAH PAKET')
            ->assertSeeText('Total Paket Aktif')
            ->assertSeeText('Revenue Bulan Ini')
            ->assertSeeText('Rata-rata Masa Aktif')
            ->assertSeeText('Paket Terpopuler')
            ->assertDontSeeText('Management Packages')
            ->assertSee('justify-content: flex-end;', false)
            ->assertDontSee('pkg-title-supra', false)
            ->assertDontSee('pkg-title-accent', false);
    }
}
