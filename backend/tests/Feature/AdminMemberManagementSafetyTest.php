<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminMemberManagementSafetyTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private User $memberUser;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $this->admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Member Safety Admin',
            'email' => uniqid('member_safety_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $this->memberUser = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Read Only Member',
            'email' => uniqid('readonly_member_', true).'@example.test',
            'phone' => '081200001111',
            'password' => 'original-password',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $this->memberUser->id,
            'member_code' => uniqid('SAFE-'),
            'gender' => 'female',
            'birth_date' => '2000-01-02',
            'height_cm' => 165,
            'weight_kg' => 58,
            'fitness_goal' => 'Menjaga kebugaran',
            'joined_at' => now(),
        ]);
    }

    public function test_manage_page_is_read_only_for_member_owned_profile_and_has_separate_admin_controls(): void
    {
        $response = $this->adminGet(route('admin.members.edit', $this->member));

        $response->assertOk()
            ->assertSee('Detail & Kelola Member', false)
            ->assertSeeText('Data profil member dikelola oleh member melalui aplikasi mobile.')
            ->assertSeeText('Password lama tidak dapat dilihat')
            ->assertSeeText('Kontrol Admin')
            ->assertSeeText('Reset Password Member')
            ->assertSeeText('Password lama tidak dapat dilihat.')
            ->assertSee('name="status"', false)
            ->assertSee('name="password"', false)
            ->assertSee('name="password_confirmation"', false)
            ->assertSee('name="password_reset_confirmation"', false)
            ->assertSee('id="passwordResetButton" class="btn btn-secondary" disabled', false)
            ->assertDontSeeText('Kelola Membership Manual')
            ->assertDontSee('name="membership_plan_id"', false)
            ->assertDontSee('name="duration_months"', false)
            ->assertDontSee('name="payment_status"', false)
            ->assertDontSee('name="name"', false)
            ->assertDontSee('name="email"', false)
            ->assertDontSee('name="phone"', false)
            ->assertDontSee('name="gender"', false)
            ->assertDontSee('name="birth_date"', false)
            ->assertDontSee('name="height_cm"', false)
            ->assertDontSee('name="weight_kg"', false)
            ->assertDontSee('name="fitness_goal"', false);
    }

    public function test_crafted_status_update_changes_only_account_status_and_never_creates_membership(): void
    {
        $password = $this->memberUser->password;
        $profileSnapshot = $this->member->only([
            'gender', 'birth_date', 'height_cm', 'weight_kg', 'fitness_goal',
        ]);
        $membershipCount = $this->member->memberships()->count();

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->put(route('admin.members.update', $this->member), [
                'status' => 'inactive',
                'name' => 'Hacked Name',
                'email' => 'hacked@example.test',
                'phone' => '000',
                'password' => 'hacked-password',
                'gender' => 'male',
                'birth_date' => '1999-12-31',
                'height_cm' => 200,
                'weight_kg' => 200,
                'fitness_goal' => 'Hacked goal',
                'membership_plan_id' => 999999,
            ])->assertRedirect(route('admin.members.edit', $this->member));

        $user = $this->memberUser->fresh();
        $profile = $this->member->fresh();
        $this->assertSame('inactive', $user->status);
        $this->assertSame('Read Only Member', $user->name);
        $this->assertNotSame('hacked@example.test', $user->email);
        $this->assertSame('081200001111', $user->phone);
        $this->assertSame($password, $user->password);
        $this->assertTrue(Hash::check('original-password', $user->password));
        $this->assertSame($profileSnapshot['gender'], $profile->gender);
        $this->assertSame($profileSnapshot['birth_date']->toDateString(), $profile->birth_date->toDateString());
        $this->assertSame((string) $profileSnapshot['height_cm'], (string) $profile->height_cm);
        $this->assertSame((string) $profileSnapshot['weight_kg'], (string) $profile->weight_kg);
        $this->assertSame($profileSnapshot['fitness_goal'], $profile->fitness_goal);
        $this->assertSame($membershipCount, $profile->memberships()->count());
    }

    public function test_password_reset_requires_valid_confirmation_hashes_value_and_logs_no_secret(): void
    {
        $oldHash = $this->memberUser->password;

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->put(route('admin.members.password.update', $this->member), [
                'password' => 'short',
                'password_confirmation' => 'different',
            ])->assertSessionHasErrors(['password', 'password_reset_confirmation']);
        $this->assertSame($oldHash, $this->memberUser->fresh()->password);

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->put(route('admin.members.password.update', $this->member), [
                'password' => 'new-password-123',
                'password_confirmation' => 'not-the-same',
                'password_reset_confirmation' => '1',
            ])->assertSessionHasErrors('password');
        $this->assertSame($oldHash, $this->memberUser->fresh()->password);

        $this->withSession(['admin_user_id' => $this->admin->id])
            ->put(route('admin.members.password.update', $this->member), [
                'password' => 'new-password-123',
                'password_confirmation' => 'new-password-123',
                'password_reset_confirmation' => '1',
            ])->assertRedirect(route('admin.members.edit', $this->member))
            ->assertSessionHas('success', 'Password member berhasil direset.');

        $newHash = $this->memberUser->fresh()->password;
        $this->assertNotSame($oldHash, $newHash);
        $this->assertTrue(Hash::check('new-password-123', $newHash));
        $this->assertFalse(Hash::check('original-password', $newHash));
        $log = ActivityLog::query()->where('action', 'member_password_reset')->latest('id')->firstOrFail();
        $this->assertSame($this->admin->id, $log->user_id);
        $this->assertSame($this->member->id, $log->model_id);
        $this->assertNull($log->old_data);
        $this->assertNull($log->new_data);
        $encoded = json_encode($log->toArray());
        $this->assertStringNotContainsString('new-password-123', $encoded);
        $this->assertStringNotContainsString($newHash, $encoded);
    }

    public function test_password_reset_endpoint_requires_admin_session_and_manual_membership_route_is_removed(): void
    {
        $this->put(route('admin.members.password.update', $this->member), [
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
            'password_reset_confirmation' => '1',
        ])->assertRedirect(route('admin.login'));
        $this->assertTrue(Hash::check('original-password', $this->memberUser->fresh()->password));

        $this->assertFalse(collect(app('router')->getRoutes()->getRoutes())
            ->contains(fn ($route) => $route->getName() === 'admin.members.manual-memberships.store'));
    }

    public function test_index_action_is_labeled_manage_member(): void
    {
        $this->adminGet(route('admin.members.index'))
            ->assertOk()
            ->assertSee('title="Kelola member"', false)
            ->assertDontSee('title="Edit member"', false)
            ->assertDontSee('title="Hapus member"', false)
            ->assertDontSee('method="POST" action="'.route('admin.members.destroy', $this->member).'"', false);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }
}
