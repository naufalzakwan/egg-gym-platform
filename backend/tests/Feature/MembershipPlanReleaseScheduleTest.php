<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use App\Services\Admin\MembershipRevenueService;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MembershipPlanReleaseScheduleTest extends TestCase
{
    use DatabaseTransactions;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_upcoming_plan_auto_launches_on_release_date_without_row_update(): void
    {
        $this->travelToJakarta('2026-07-23 23:30:00');
        [$user, $member] = $this->createMember();
        $plan = $this->createPlan('Scheduled Ramadan Package', '2026-07-24', true);
        $plan->update(['features_json' => ['Gym access', 'Benefit custom tetap']]);

        $this->getJson('/api/v1/public/membership-plans')
            ->assertOk()
            ->assertJsonMissing(['id' => $plan->id]);

        Sanctum::actingAs($user, [], 'sanctum');
        $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $plan->id,
            'payment_method' => 'bri_va',
        ])->assertUnprocessable();

        $this->travelToJakarta('2026-07-24 00:00:00');
        $this->getJson('/api/v1/public/membership-plans')
            ->assertOk()
            ->assertJsonFragment(['id' => $plan->id, 'name' => $plan->name])
            ->assertJsonFragment(['features' => ['Akses gym', 'Benefit custom tetap']]);
        $this->assertSame(['Gym access', 'Benefit custom tetap'], $plan->fresh()->features_json);

        Http::fake([
            '*/api/transactioncreate/bri_va' => Http::response([
                'payment' => [
                    'order_id' => 'release-provider-order',
                    'payment_number' => '1234567890',
                    'fee' => 1000,
                    'total_payment' => 251000,
                    'expired_at' => '2026-07-23T19:00:00.000000000Z',
                ],
            ]),
        ]);
        $this->postJson('/api/v1/member/payments/checkout', [
            'membership_plan_id' => $plan->id,
            'payment_method' => 'bri_va',
        ])->assertCreated();

        $this->assertDatabaseHas('membership_plans', [
            'id' => $plan->id,
            'release_date' => '2026-07-24',
            'is_active' => true,
        ]);
        $this->assertDatabaseHas('transactions', [
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'status' => 'pending',
        ]);
    }

    public function test_admin_shows_upcoming_badge_and_active_stats_exclude_future_and_disabled_plans(): void
    {
        $this->travelToJakarta('2026-07-23 12:00:00');
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Release Schedule Admin',
            'email' => uniqid('release_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $upcoming = $this->createPlan('Upcoming Admin Package', '2026-08-10', true);
        $disabled = $this->createPlan('Disabled Released Package', null, false);
        $effectiveActiveCount = MembershipPlan::query()->availableForPurchase()->count();

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.membership-plans.index'))
            ->assertOk()
            ->assertSeeText('Upcoming')
            ->assertSeeText('Akan rilis: 10 Agustus 2026')
            ->assertSee('pkg-badge-upcoming', false)
            ->assertSee('<div class="kpi-card__value">'.$effectiveActiveCount.'</div>', false);

        $this->assertSame('upcoming', $upcoming->fresh()->effective_status);
        $this->assertSame('inactive', $disabled->fresh()->effective_status);
        $this->assertFalse($upcoming->fresh()->isAvailableForPurchase());
        $this->assertFalse($disabled->fresh()->isAvailableForPurchase());
    }

    public function test_admin_create_and_edit_reject_today_or_past_release_dates(): void
    {
        $this->travelToJakarta('2026-07-23 23:30:00');
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Release Validation Admin',
            'email' => uniqid('release_validation_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $plan = $this->createPlan('Release Validation Package', null, true);
        $payload = [
            'name' => 'Invalid Today Release Package',
            'price' => 150000,
            'duration_days' => 30,
            'release_date' => '2026-07-23',
            'features_text' => 'Gym access',
            'is_active' => '1',
        ];

        $this->withSession(['admin_user_id' => $admin->id])
            ->from(route('admin.membership-plans.index'))
            ->post(route('admin.membership-plans.store'), $payload)
            ->assertRedirect(route('admin.membership-plans.index'))
            ->assertSessionHasErrors([
                'release_date' => 'Tanggal rilis harus lebih besar dari hari ini.',
            ]);
        $this->assertDatabaseMissing('membership_plans', ['name' => $payload['name']]);

        $payload['name'] = $plan->name;
        $payload['release_date'] = '2026-07-22';
        $this->withSession(['admin_user_id' => $admin->id])
            ->from(route('admin.membership-plans.index'))
            ->put(route('admin.membership-plans.update', $plan), $payload)
            ->assertRedirect(route('admin.membership-plans.index'))
            ->assertSessionHasErrors('release_date');
        $this->assertNull($plan->fresh()->release_date);

        $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.membership-plans.index'))
            ->assertOk()
            ->assertSee('min="2026-07-24"', false)
            ->assertSeeText('Tanggal rilis opsional untuk paket Upcoming. Kosongkan jika paket ingin langsung aktif sesuai Status Aktif.')
            ->assertSeeText('Tanggal rilis harus lebih besar dari hari ini.');

        $futurePayload = [
            'name' => 'Scheduled Toggle Normalization Package',
            'price' => 175000,
            'duration_days' => 30,
            'release_date' => '2026-07-24',
            'features_text' => 'Gym access',
            'is_active' => '0',
        ];
        $this->withSession(['admin_user_id' => $admin->id])
            ->post(route('admin.membership-plans.store'), $futurePayload)
            ->assertRedirect(route('admin.membership-plans.index'));
        $this->assertDatabaseHas('membership_plans', [
            'name' => $futurePayload['name'],
            'release_date' => '2026-07-24',
            'is_active' => true,
        ]);
    }

    public function test_membership_package_kpis_use_only_valid_real_data(): void
    {
        $this->travelToJakarta('2026-07-23 12:00:00');
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::create([
            'role_id' => $adminRole->id,
            'name' => 'Package KPI Admin',
            'email' => uniqid('package_kpi_admin_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        [, $member] = $this->createMember();
        $popular = $this->createPlan('Real KPI Popular Package', null, true);
        $upcoming = $this->createPlan('Real KPI Upcoming Package', '2026-08-23', true);

        $currentMaximum = (int) (Transaction::query()
            ->whereIn('status', ['completed', 'paid'])
            ->whereNotNull('membership_plan_id')
            ->whereBetween('paid_at', [now()->startOfMonth(), now()])
            ->selectRaw('COUNT(*) as total')
            ->groupBy('membership_plan_id')
            ->orderByDesc('total')
            ->value('total') ?? 0);

        for ($index = 0; $index <= $currentMaximum; $index++) {
            Transaction::create([
                'member_profile_id' => $member->id,
                'membership_plan_id' => $popular->id,
                'reference_code' => uniqid('KPI-PAID-'),
                'title' => 'Paid KPI membership',
                'payment_method' => 'cash',
                'amount' => 125000,
                'total_payment' => null,
                'status' => 'paid',
                'paid_at' => now(),
            ]);
        }
        Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $upcoming->id,
            'reference_code' => uniqid('KPI-PENDING-'),
            'title' => 'Pending must be ignored',
            'payment_method' => 'cash',
            'amount' => 999999999,
            'total_payment' => 999999999,
            'status' => 'pending',
            'paid_at' => null,
        ]);
        MemberMembership::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $popular->id,
            'start_date' => '2026-07-01',
            'end_date' => '2026-08-30',
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
        MemberMembership::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $upcoming->id,
            'start_date' => '2026-07-01',
            'end_date' => '2027-07-01',
            'status' => 'active',
            'payment_status' => 'pending',
        ]);

        $expectedRevenue = app(MembershipRevenueService::class)->netBetween(
            now()->startOfMonth(),
            now()->endOfMonth()
        );
        $validMemberships = MemberMembership::query()
            ->where('status', 'active')
            ->where('payment_status', 'paid')
            ->whereNotNull('start_date')
            ->whereNotNull('end_date')
            ->get();
        $expectedAverageDays = (int) round((float) $validMemberships
            ->avg(fn (MemberMembership $membership) => $membership->start_date->diffInDays($membership->end_date)));
        $expectedAverageLabel = $expectedAverageDays.' hari';

        $response = $this->withSession(['admin_user_id' => $admin->id])
            ->get(route('admin.membership-plans.index'))
            ->assertOk()
            ->assertDontSee('.pkg-card.is-upcoming', false)
            ->assertSeeText('Rata-rata Masa Aktif')
            ->assertSeeText('Rata-rata durasi membership aktif')
            ->assertSeeText($expectedAverageLabel);

        $kpi = $response->viewData('kpi');
        $this->assertSame(MembershipPlan::query()->availableForPurchase()->count(), $kpi['total_active']);
        $this->assertSame($expectedRevenue, $kpi['revenue_this_month']);
        $this->assertSame($expectedAverageDays, $kpi['average_active_days']);
        $this->assertSame($expectedAverageLabel, $kpi['average_active_label']);
        $this->assertSame($popular->name, $kpi['popular_plan']);
    }

    private function travelToJakarta(string $dateTime): void
    {
        $now = CarbonImmutable::parse($dateTime, 'Asia/Jakarta');
        Carbon::setTestNow($now);
        CarbonImmutable::setTestNow($now);
    }

    private function createMember(): array
    {
        $role = Role::firstOrCreate(['name' => 'member']);
        $user = User::create([
            'role_id' => $role->id,
            'name' => 'Scheduled Package Member',
            'email' => uniqid('release_member_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
        $profile = MemberProfile::create([
            'user_id' => $user->id,
            'member_code' => strtoupper(uniqid('REL-')),
            'joined_at' => now()->toDateString(),
        ]);

        return [$user, $profile];
    }

    private function createPlan(string $name, ?string $releaseDate, bool $active): MembershipPlan
    {
        return MembershipPlan::create([
            'name' => $name,
            'slug' => uniqid('release-plan-'),
            'description' => 'Release schedule test',
            'price' => 250000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'release_date' => $releaseDate,
            'features_json' => ['Scheduled access'],
            'is_active' => $active,
        ]);
    }
}
