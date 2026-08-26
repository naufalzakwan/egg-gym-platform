<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use App\Services\Admin\MembershipRevenueService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminRevenueConsistencyTest extends TestCase
{
    use DatabaseTransactions;

    public function test_admin_membership_revenue_pages_share_net_query_and_full_rupiah_formatter(): void
    {
        $this->travelTo(CarbonImmutable::parse('2036-04-20 12:00:00', 'Asia/Jakarta'));
        $admin = $this->createUser('admin', 'Revenue Consistency Admin');
        $memberUser = $this->createUser('member', 'Revenue Consistency Member');
        $member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => 'REVENUE-'.uniqid(),
            'joined_at' => now(),
        ]);
        $plan = MembershipPlan::create([
            'name' => 'Revenue Consistency Plan',
            'slug' => 'revenue-consistency-'.uniqid(),
            'description' => 'Revenue source fixture',
            'price' => 9720000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => 'NET-REVENUE-'.uniqid(),
            'title' => 'Membership revenue',
            'payment_method' => 'qris',
            'amount' => 9720000,
            'fee' => 280000,
            'total_payment' => 10000000,
            'status' => 'completed',
            'paid_at' => '2036-04-10 10:00:00',
        ]);
        Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => 'PREVIOUS-NET-REVENUE-'.uniqid(),
            'title' => 'Previous month membership revenue',
            'payment_method' => 'qris',
            'amount' => 9380000,
            'fee' => 120000,
            'total_payment' => 9500000,
            'status' => 'paid',
            'paid_at' => '2036-03-10 10:00:00',
        ]);
        Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => null,
            'reference_code' => 'PT-REVENUE-'.uniqid(),
            'title' => 'PT payment excluded',
            'payment_method' => 'qris',
            'amount' => 99000000,
            'fee' => 1000000,
            'total_payment' => 100000000,
            'status' => 'completed',
            'paid_at' => '2036-04-11 10:00:00',
        ]);

        $service = app(MembershipRevenueService::class);
        $this->assertSame(9720000.0, $service->netBetween(now()->startOfMonth(), now()->endOfMonth()));
        $this->assertSame('Rp 9.720.000', $service->formatRupiah(9720000));

        foreach (['admin.membership-plans.index', 'admin.dashboard'] as $route) {
            $this->withSession(['admin_user_id' => $admin->id])
                ->get(route($route))
                ->assertOk()
                ->assertSeeText('Rp 9.720.000')
                ->assertDontSeeText('Rp 9.8jt')
                ->assertDontSeeText('Rp 9,7M');
        }

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.transactions.index', ['search' => 'NET-REVENUE-']))
            ->assertOk()
            ->assertSeeText('Rp 19.100.000')
            ->assertSeeText('Seluruh transaksi Membership sukses');

        $report = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.reports.index'))
            ->assertOk()
            ->assertSeeText('Rp 19.100.000');
        $reportKpi = $report->viewData('kpi');
        $reportTrend = $report->viewData('revenueTrend');

        $this->assertSame(19100000.0, $reportKpi['revenue_value']);
        $this->assertSame(19100000.0, (float) collect($reportTrend)->sum('value'));
        $this->assertSame('Rp 9.720.000', $reportTrend[3]['value_label']);
        $this->assertSame(2, $reportKpi['successful_transactions']);
    }

    private function createUser(string $roleName, string $name): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid($roleName.'_revenue_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }
}
