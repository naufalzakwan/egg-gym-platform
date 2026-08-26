<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminMemberMembershipStatusTest extends TestCase
{
    use DatabaseTransactions;

    public function test_filter_and_status_badge_share_active_membership_definition(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Member Status Test Admin',
            'email' => uniqid('member_status_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        $inactiveProfile = $this->createMember($memberRole, 'No Package Member');
        $activeProfile = $this->createMember($memberRole, 'Active Package Member');
        $plan = MembershipPlan::create([
            'name' => 'Status Test Package',
            'slug' => uniqid('status-test-'),
            'description' => 'Test package',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => [],
            'is_active' => true,
        ]);
        MemberMembership::create([
            'member_profile_id' => $activeProfile->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addMonth()->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index', ['status' => 'inactive', 'search' => $inactiveProfile->member_code]))
            ->assertOk()
            ->assertSeeText('No Package Member')
            ->assertSee('pill pill-nonaktif', false)
            ->assertSeeText('Nonaktif')
            ->assertDontSeeText('Active Package Member');

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index', ['status' => 'active', 'search' => $activeProfile->member_code]))
            ->assertOk()
            ->assertSeeText('Active Package Member')
            ->assertSee('pill pill-aktif', false)
            ->assertSeeText('Aktif')
            ->assertDontSeeText('No Package Member');
    }

    public function test_member_summary_cards_use_real_membership_queries(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Summary Test Admin',
            'email' => uniqid('summary_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $profile = $this->createMember($memberRole, 'Expiring Active Member');
        $plan = MembershipPlan::create([
            'name' => 'Summary Test Package',
            'slug' => uniqid('summary-test-'),
            'description' => 'Summary package',
            'price' => 100000,
            'duration_days' => 14,
            'billing_period' => 'monthly',
            'features_json' => [],
            'is_active' => true,
        ]);
        MemberMembership::create([
            'member_profile_id' => $profile->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addDays(14)->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);

        $totalMembers = MemberProfile::query()->count();
        $activeMemberships = MemberMembership::query()
            ->currentlyActive()->distinct()->count('member_profile_id');

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index', ['search' => $profile->member_code]))
            ->assertOk()
            ->assertSeeText('Active Membership')
            ->assertSeeText(number_format($totalMembers, 0, ',', '.'))
            ->assertSeeText(number_format($activeMemberships, 0, ',', '.'))
            ->assertSeeText('Berakhir dalam 30 hari');
    }

    public function test_package_chip_filters_active_memberships_without_duration_options(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Package Filter Admin',
            'email' => uniqid('package_filter_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $annualPlan = $this->createPlan('Annual Pro Filter Test');
        $starterPlan = $this->createPlan('Starter Pack Filter Test');
        $annualShort = $this->createMember($memberRole, 'Annual Short Member');
        $annualLong = $this->createMember($memberRole, 'Annual Long Member');
        $starter = $this->createMember($memberRole, 'Starter Member');
        $this->createActiveMembership($annualShort, $annualPlan, 30);
        $this->createActiveMembership($annualLong, $annualPlan, 365);
        $this->createActiveMembership($starter, $starterPlan, 30);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index', [
                'status' => 'active',
                'plan' => $annualPlan->name,
            ]))
            ->assertOk()
            ->assertSeeText('Annual Short Member')
            ->assertSeeText('Annual Long Member')
            ->assertDontSeeText('Starter Member')
            ->assertSee('class="mbr-tab active">'.$annualPlan->name, false)
            ->assertDontSee('name="tiers[]"', false)
            ->assertDontSeeText('1 Bulan')
            ->assertDontSeeText('12 Bulan');
    }

    public function test_package_chips_only_show_effectively_active_plans(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Effective Package Chip Admin',
            'email' => uniqid('effective_chip_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $active = $this->createPlan('Effective Active Chip Plan');
        $inactive = $this->createPlan('Effective Inactive Chip Plan');
        $inactive->update(['is_active' => false]);
        $upcoming = $this->createPlan('Effective Upcoming Chip Plan');
        $upcoming->update(['release_date' => now()->addMonth()->toDateString()]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index'))
            ->assertOk()
            ->assertSeeText('Semua Paket')
            ->assertSeeText($active->name)
            ->assertDontSeeText($inactive->name)
            ->assertDontSeeText($upcoming->name);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.members.index', ['plan' => $upcoming->name]))
            ->assertOk()
            ->assertSee('class="mbr-tab active">Semua Paket', false)
            ->assertDontSeeText($upcoming->name);
    }

    private function createMember(Role $role, string $name): MemberProfile
    {
        $user = User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid('member_status_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);

        return MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => strtoupper(uniqid('MST-')),
            'joined_at' => now()->toDateString(),
        ]);
    }

    private function createPlan(string $name): MembershipPlan
    {
        return MembershipPlan::create([
            'name' => $name,
            'slug' => uniqid('package-filter-'),
            'description' => 'Package filter test',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => [],
            'is_active' => true,
        ]);
    }

    private function createActiveMembership(MemberProfile $profile, MembershipPlan $plan, int $days): void
    {
        MemberMembership::create([
            'member_profile_id' => $profile->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addDays($days)->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
    }
}
