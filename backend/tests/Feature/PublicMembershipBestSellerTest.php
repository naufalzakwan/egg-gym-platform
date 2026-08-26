<?php

namespace Tests\Feature;

use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use App\Services\Membership\MembershipPlanPopularityService;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class PublicMembershipBestSellerTest extends TestCase
{
    use DatabaseTransactions;

    private MemberProfile $member;

    protected function setUp(): void
    {
        parent::setUp();

        // This database can contain local fixtures; popularity assertions must be isolated.
        Transaction::query()->delete();

        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => 'Best Seller Member',
            'email' => uniqid('best_seller_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $this->member = MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => strtoupper(uniqid('BST-')),
            'joined_at' => now()->toDateString(),
        ]);
    }

    public function test_no_successful_transactions_marks_every_public_plan_false(): void
    {
        $first = $this->createPlan('No Sales One');
        $second = $this->createPlan('No Sales Two');

        foreach (['pending', 'failed', 'expired'] as $status) {
            $this->createTransaction($first, $status, 999999, now());
        }

        $plans = $this->publicPlansById();

        $this->assertFalse($plans[$first->id]['is_best_seller']);
        $this->assertFalse($plans[$second->id]['is_best_seller']);
        $this->assertSame(0, $plans->where('is_best_seller', true)->count());
        $this->assertNull(app(MembershipPlanPopularityService::class)->bestSellerPlanId());
    }

    public function test_purchase_count_wins_before_revenue(): void
    {
        $morePurchases = $this->createPlan('Count Winner');
        $moreRevenue = $this->createPlan('Revenue Loser');
        $this->createTransaction($morePurchases, 'paid', 10, now()->subDay());
        $this->createTransaction($morePurchases, 'completed', 10, now());
        $this->createTransaction($moreRevenue, 'paid', 1000000, now()->addDay());

        $this->assertSame($morePurchases->id, app(MembershipPlanPopularityService::class)->bestSellerPlanId());
    }

    public function test_equal_count_uses_revenue_then_latest_success_time(): void
    {
        $lowerRevenue = $this->createPlan('Lower Revenue');
        $older = $this->createPlan('Older Revenue Winner');
        $latest = $this->createPlan('Latest Revenue Winner');

        $this->createTransaction($lowerRevenue, 'paid', 99, now()->addDays(3));
        $this->createTransaction($older, 'completed', 100, now()->subDays(2));
        $this->createTransaction($latest, 'paid', 100, now()->subDay());

        $this->assertSame($latest->id, app(MembershipPlanPopularityService::class)->bestSellerPlanId());
    }

    public function test_latest_time_coalesces_paid_at_to_created_at_and_full_tie_uses_lower_id(): void
    {
        $lowerId = $this->createPlan('Lower ID');
        $laterCreated = $this->createPlan('Later Created');
        $olderPaid = $this->createPlan('Older Paid');
        $tieAt = now()->subHour();

        $this->createTransaction($lowerId, 'paid', 100, $tieAt, null);
        $this->createTransaction($laterCreated, 'completed', 100, $tieAt, null);
        $this->createTransaction($olderPaid, 'paid', 100, now(), now()->subDay());

        $this->assertSame($lowerId->id, app(MembershipPlanPopularityService::class)->bestSellerPlanId());
    }

    public function test_ineligible_top_plans_are_skipped_for_the_public_badge(): void
    {
        $deleted = $this->createPlan('Deleted Top');
        $inactive = $this->createPlan('Inactive Top', ['is_active' => false]);
        $upcoming = $this->createPlan('Upcoming Top', ['release_date' => now()->addWeek()->toDateString()]);
        $eligible = $this->createPlan('Eligible Seller');

        foreach ([[$deleted, 6], [$inactive, 5], [$upcoming, 4], [$eligible, 2]] as [$plan, $count]) {
            for ($index = 0; $index < $count; $index++) {
                $this->createTransaction($plan, 'paid', 100 + $index, now()->subMinutes($index));
            }
        }
        $deleted->delete();

        $plans = $this->publicPlansById();

        $this->assertFalse($plans->has($deleted->id));
        $this->assertFalse($plans->has($inactive->id));
        $this->assertFalse($plans->has($upcoming->id));
        $this->assertTrue($plans[$eligible->id]['is_best_seller']);
        $this->assertSame(1, $plans->where('is_best_seller', true)->count());
    }

    public function test_public_endpoint_and_admin_insights_use_the_service_winner(): void
    {
        $winner = $this->createPlan('Shared All Time Winner');
        $runnerUp = $this->createPlan('Shared Runner Up');
        $this->createTransaction($winner, 'completed', 100, now()->subYear());
        $this->createTransaction($winner, 'paid', 100, now()->subMonths(2));
        $this->createTransaction($runnerUp, 'paid', 1000, now());

        $serviceWinner = app(MembershipPlanPopularityService::class)->bestSellerPlanId();
        $plans = $this->publicPlansById();
        $this->assertSame($winner->id, $serviceWinner);
        $this->assertTrue($plans[$winner->id]['is_best_seller']);
        $this->assertSame(1, $plans->where('is_best_seller', true)->count());

        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Best Seller Admin',
            'email' => uniqid('best_seller_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $session = ['admin_user_id' => $admin->id];

        $dashboard = $this->withSession($session)->get(route('admin.dashboard'))->assertOk();
        $plansPage = $this->withSession($session)->get(route('admin.membership-plans.index'))->assertOk();

        $this->assertSame($winner->name, $dashboard->viewData('quickInsights')['popular_plan']);
        $this->assertSame($winner->name, $plansPage->viewData('kpi')['popular_plan']);
    }

    private function publicPlansById()
    {
        return collect($this->getJson('/api/v1/public/membership-plans')
            ->assertOk()
            ->json('data'))
            ->keyBy('id');
    }

    private function createPlan(string $name, array $overrides = []): MembershipPlan
    {
        return MembershipPlan::create(array_merge([
            'name' => $name,
            'slug' => uniqid('best-seller-plan-'),
            'description' => 'Popularity test plan',
            'price' => 100000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'release_date' => null,
            'features_json' => [],
            'is_active' => true,
        ], $overrides));
    }

    private function createTransaction(
        MembershipPlan $plan,
        string $status,
        int $amount,
        $createdAt,
        $paidAt = false,
    ): Transaction {
        return Transaction::forceCreate([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => uniqid('BEST-SELLER-TX-'),
            'title' => 'Popularity test sale',
            'payment_method' => 'cash',
            'amount' => $amount,
            'status' => $status,
            'paid_at' => $paidAt === false ? $createdAt : $paidAt,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }
}
