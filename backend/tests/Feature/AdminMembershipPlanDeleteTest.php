<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminMembershipPlanDeleteTest extends TestCase
{
    use DatabaseTransactions;

    public function test_admin_can_soft_delete_package_with_active_member_without_losing_history(): void
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Package Delete Admin',
            'email' => uniqid('package_delete_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $member = User::create([
            'role_id' => $memberRole->id,
            'name' => 'Historical Package Member',
            'email' => uniqid('package_delete_member_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $profile = MemberProfile::create([
            'user_id' => $member->id,
            'member_code' => strtoupper(uniqid('DEL-')),
            'joined_at' => now()->toDateString(),
        ]);
        $plan = MembershipPlan::create([
            'name' => 'Deletable Active Package',
            'slug' => uniqid('deletable-active-'),
            'description' => 'Soft delete history test',
            'price' => 500000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['History remains'],
            'is_active' => true,
        ]);
        $membership = MemberMembership::create([
            'member_profile_id' => $profile->id,
            'membership_plan_id' => $plan->id,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addMonth()->toDateString(),
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
        $transaction = Transaction::create([
            'member_profile_id' => $profile->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => uniqid('TRX-DEL-'),
            'title' => 'Membership '.$plan->name,
            'payment_method' => 'cash',
            'amount' => 500000,
            'total_payment' => 500000,
            'status' => 'completed',
            'paid_at' => now(),
        ]);

        $this->withSession(['admin_user_id' => $admin->id])
            ->delete(route('admin.membership-plans.destroy', $plan))
            ->assertRedirect(route('admin.membership-plans.index'))
            ->assertSessionHas('success');

        $this->assertSoftDeleted('membership_plans', ['id' => $plan->id]);
        $this->assertDatabaseHas('membership_plans', ['id' => $plan->id, 'is_active' => false]);
        $this->assertDatabaseHas('member_memberships', ['id' => $membership->id]);
        $this->assertDatabaseHas('transactions', ['id' => $transaction->id]);
        $this->assertNull(MembershipPlan::query()->find($plan->id));
        $this->assertSame($plan->name, $membership->fresh()->membershipPlan?->name);
        $this->assertSame($plan->name, $transaction->fresh()->membershipPlan?->name);
    }

    public function test_all_package_cards_render_enabled_delete_buttons(): void
    {
        $role = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $role->id,
            'name' => 'Delete Button Admin',
            'email' => uniqid('delete_button_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        MembershipPlan::create([
            'name' => 'Visible Delete Package',
            'slug' => uniqid('visible-delete-'),
            'price' => 250000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.membership-plans.index'));

        $response->assertOk()
            ->assertDontSee('pkg-icon-btn is-danger is-disabled', false)
            ->assertSee('Histori membership dan transaksi lama tetap tersimpan.', false);
    }
}
