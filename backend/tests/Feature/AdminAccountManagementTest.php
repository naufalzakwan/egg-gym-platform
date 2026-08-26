<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminAccountManagementTest extends TestCase
{
    use DatabaseTransactions;

    private Role $adminRole;

    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->adminRole = Role::firstOrCreate(['name' => 'admin']);
        $this->owner = $this->createAdmin('Owner Admin', 'owner@example.test', true);
    }

    public function test_owner_can_create_update_and_toggle_admin_with_safe_audit_data(): void
    {
        $this->ownerRequest()->post(route('admin.admin-accounts.store'), [
            'name' => 'Petugas Keuangan',
            'email' => 'finance@example.test',
            'password' => 'securePass123',
            'password_confirmation' => 'securePass123',
            'status' => 'active',
        ])->assertRedirect(route('admin.admin-accounts.index'));

        $admin = User::query()->where('email', 'finance@example.test')->firstOrFail();
        $this->assertSame($this->adminRole->id, $admin->role_id);
        $this->assertTrue(Hash::check('securePass123', $admin->password));
        $this->assertFalse($admin->is_admin_owner);
        $this->assertSame('active', $admin->status);

        $created = ActivityLog::query()->where('action', 'admin_account_created')->latest('id')->firstOrFail();
        $this->assertSame($this->owner->id, $created->user_id);
        $this->assertSame($admin->id, $created->model_id);
        $this->assertSame('finance@example.test', $created->new_data['email']);
        $this->assertArrayNotHasKey('password', $created->new_data);
        $this->assertStringNotContainsString('securePass123', json_encode($created->toArray(), JSON_THROW_ON_ERROR));

        $this->ownerRequest()->put(route('admin.admin-accounts.update', $admin), [
            'name' => 'Petugas Finance',
            'email' => 'finance.updated@example.test',
        ])->assertRedirect(route('admin.admin-accounts.index'));
        $updated = ActivityLog::query()->where('action', 'admin_account_updated')->latest('id')->firstOrFail();
        $this->assertSame('finance@example.test', $updated->old_data['email']);
        $this->assertSame('finance.updated@example.test', $updated->new_data['email']);
        $this->assertArrayNotHasKey('password', $updated->old_data);
        $this->assertArrayNotHasKey('password', $updated->new_data);

        $this->ownerRequest()->patch(route('admin.admin-accounts.toggle-status', $admin))
            ->assertRedirect();
        $admin->refresh();
        $this->assertSame('inactive', $admin->status);
        $deactivated = ActivityLog::query()->where('action', 'admin_account_deactivated')->latest('id')->firstOrFail();
        $this->assertSame('active', $deactivated->old_data['status']);
        $this->assertSame('inactive', $deactivated->new_data['status']);
    }

    public function test_regular_admin_cannot_access_management_and_owner_cannot_disable_self(): void
    {
        $regular = $this->createAdmin('Regular Admin', 'regular@example.test');

        $this->ownerRequest()->get(route('admin.dashboard'))
            ->assertOk()
            ->assertDontSeeText('Manajemen Admin')
            ->assertSeeText('Admin Utama');
        $settings = $this->ownerRequest()->get(route('admin.settings.index'));
        $settings->assertOk()
            ->assertSeeText('Manajemen Akun Admin')
            ->assertSeeText('Kelola akun petugas Admin, status akses, dan identitas yang tercatat pada Audit Trail.')
            ->assertSeeText('Kelola Akun')
            ->assertSee('href="'.route('admin.admin-accounts.index').'"', false)
            ->assertViewHas('adminAccountMetrics', function (array $metrics) {
                $adminQuery = User::query()->whereHas('role', fn ($query) => $query->where('name', 'admin'));

                return $metrics['total'] === (clone $adminQuery)->count()
                    && $metrics['active'] === (clone $adminQuery)->where('status', 'active')->count()
                    && $metrics['inactive'] === (clone $adminQuery)->where('status', 'inactive')->count();
            });
        $management = $this->ownerRequest()->get(route('admin.admin-accounts.index'));
        $management->assertOk()
            ->assertSeeText('Akun Anda')
            ->assertSee('data-admin-id="'.$this->owner->id.'" data-current-admin', false)
            ->assertSee('title="Akun yang sedang digunakan tidak dapat dinonaktifkan."', false)
            ->assertDontSee('action="'.route('admin.admin-accounts.toggle-status', $this->owner).'"', false)
            ->assertSee('action="'.route('admin.admin-accounts.toggle-status', $regular).'"', false);
        $this->withSession(['admin_user_id' => $regular->id])
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertDontSeeText('Manajemen Admin');
        $this->withSession(['admin_user_id' => $regular->id])
            ->get(route('admin.settings.index'))
            ->assertOk()
            ->assertViewHas('adminAccountMetrics', null)
            ->assertDontSeeText('Manajemen Akun Admin')
            ->assertDontSee('data-admin-account-card', false);
        $this->withSession(['admin_user_id' => $regular->id])
            ->get(route('admin.admin-accounts.index'))
            ->assertForbidden();
        $this->withSession(['admin_user_id' => $regular->id])
            ->post(route('admin.admin-accounts.store'), [
                'name' => 'Unauthorized',
                'email' => 'unauthorized@example.test',
                'password' => 'password123',
                'password_confirmation' => 'password123',
                'status' => 'active',
            ])->assertForbidden();
        $this->assertDatabaseMissing('users', ['email' => 'unauthorized@example.test']);

        $this->ownerRequest()->patch(route('admin.admin-accounts.toggle-status', $this->owner))
            ->assertStatus(422);
        $this->assertSame('active', $this->owner->fresh()->status);
    }

    public function test_active_admin_login_and_logout_are_audited_with_request_metadata(): void
    {
        $admin = $this->createAdmin('Login Admin', 'login@example.test');

        $login = $this->withServerVariables([
            'REMOTE_ADDR' => '203.0.113.10',
            'HTTP_USER_AGENT' => 'EggGym Test Browser/1.0',
        ])->post(route('admin.login.submit'), [
            'email' => $admin->email,
            'password' => 'password123',
        ]);
        $login->assertRedirect(route('admin.dashboard'))
            ->assertSessionHas('admin_user_id', $admin->id);

        $loginLog = ActivityLog::query()->where('action', 'admin_login')->latest('id')->firstOrFail();
        $this->assertSame($admin->id, $loginLog->user_id);
        $this->assertSame('203.0.113.10', $loginLog->ip_address);
        $this->assertSame('EggGym Test Browser/1.0', $loginLog->user_agent);
        $this->assertSame('Web Admin', $loginLog->new_data['source']);
        $this->assertSame('success', $loginLog->new_data['status']);
        $this->assertSame($admin->email, $loginLog->new_data['email']);
        $this->assertNotNull($admin->fresh()->last_login_at);

        $logout = $this->withServerVariables([
            'REMOTE_ADDR' => '203.0.113.10',
            'HTTP_USER_AGENT' => 'EggGym Test Browser/1.0',
        ])->post(route('admin.logout'));
        $logout->assertRedirect(route('admin.login'));
        $logoutLog = ActivityLog::query()->where('action', 'admin_logout')->latest('id')->firstOrFail();
        $this->assertSame($admin->id, $logoutLog->user_id);
        $this->assertSame('Web Admin', $logoutLog->new_data['source']);
        $this->assertSame('success', $logoutLog->new_data['status']);
        $this->assertStringNotContainsString('password123', json_encode($logoutLog->toArray(), JSON_THROW_ON_ERROR));
    }

    public function test_inactive_admin_cannot_login_and_existing_session_is_invalidated(): void
    {
        $inactive = $this->createAdmin('Inactive Admin', 'inactive@example.test', false, 'inactive');

        $this->post(route('admin.login.submit'), [
            'email' => $inactive->email,
            'password' => 'password123',
        ])->assertSessionHasErrors('email');
        $this->assertDatabaseMissing('activity_logs', [
            'user_id' => $inactive->id,
            'action' => 'admin_login',
        ]);

        $active = $this->createAdmin('Disabled Later', 'disabled.later@example.test');
        $active->update(['status' => 'inactive']);
        $this->withSession(['admin_user_id' => $active->id])
            ->get(route('admin.dashboard'))
            ->assertRedirect(route('admin.login'));
    }

    public function test_unique_email_confirmation_and_audit_trail_auth_filter(): void
    {
        $this->ownerRequest()->post(route('admin.admin-accounts.store'), [
            'name' => 'Invalid Admin',
            'email' => $this->owner->email,
            'password' => 'password123',
            'password_confirmation' => 'different123',
            'status' => 'active',
        ])->assertSessionHasErrors(['email', 'password']);

        ActivityLog::create([
            'user_id' => $this->owner->id,
            'action' => 'admin_login',
            'description' => 'Admin Owner Admin berhasil login ke Web Admin',
            'ip_address' => '198.51.100.7',
            'user_agent' => 'Audit Browser',
            'new_data' => ['source' => 'Web Admin', 'status' => 'success'],
        ]);
        $this->ownerRequest()->get(route('admin.audit-trail.index', ['category' => 'admin_auth']))
            ->assertOk()
            ->assertSeeText('Autentikasi Admin')
            ->assertSeeText('Admin Owner Admin berhasil login ke Web Admin')
            ->assertDontSeeText('IP 198.51.100.7')
            ->assertDontSeeText('Audit Browser')
            ->assertSeeText('SUCCESS');
    }

    private function createAdmin(
        string $name,
        string $email,
        bool $owner = false,
        string $status = 'active'
    ): User {
        return User::create([
            'role_id' => $this->adminRole->id,
            'name' => $name,
            'email' => $email,
            'password' => 'password123',
            'status' => $status,
            'is_admin_owner' => $owner,
        ]);
    }

    private function ownerRequest()
    {
        return $this->withSession(['admin_user_id' => $this->owner->id]);
    }
}
