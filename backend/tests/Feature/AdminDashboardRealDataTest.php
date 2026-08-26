<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\Equipment;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerScheduleDate;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminDashboardRealDataTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'admin']);
        $this->admin = User::create([
            'role_id' => $role->id,
            'name' => 'Dashboard Audit Admin',
            'email' => uniqid('dashboard_audit_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    public function test_recent_activity_uses_exact_audit_scope_real_metadata_icons_and_spanning_layout(): void
    {
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberUser = User::create(['role_id' => $memberRole->id, 'name' => 'Audit Member', 'email' => uniqid('audit_member_', true).'@example.test', 'password' => 'password', 'status' => 'active']);
        $member = MemberProfile::create(['user_id' => $memberUser->id, 'member_code' => uniqid('AUD-M-')]);
        $trainerUser = User::create(['role_id' => $trainerRole->id, 'name' => 'Audit Trainer', 'email' => uniqid('audit_trainer_', true).'@example.test', 'password' => 'password', 'status' => 'active']);
        $trainer = TrainerProfile::create(['user_id' => $trainerUser->id, 'specialty' => 'general_fitness', 'price_per_session' => 100000]);
        $plan = $this->createPlan('Audit Dashboard Plan');
        $membership = MemberMembership::create(['member_profile_id' => $member->id, 'membership_plan_id' => $plan->id, 'start_date' => now(), 'end_date' => now()->addMonth(), 'status' => 'active', 'payment_status' => 'paid']);
        $transaction = Transaction::create(['member_profile_id' => $member->id, 'membership_plan_id' => $plan->id, 'reference_code' => uniqid('AUD-TX-'), 'title' => 'Audit membership payment', 'payment_method' => 'qris', 'amount' => 100000, 'fee' => 1000, 'total_payment' => 101000, 'status' => 'completed', 'paid_at' => now()]);
        $ptTransaction = Transaction::create(['member_profile_id' => $member->id, 'membership_plan_id' => null, 'reference_code' => uniqid('AUD-PT-'), 'title' => 'Excluded PT payment', 'payment_method' => 'qris', 'amount' => 500000, 'fee' => 1000, 'total_payment' => 501000, 'status' => 'completed', 'paid_at' => now()]);
        $equipment = Equipment::create(['code' => uniqid('EQ-'), 'name' => 'Excluded Dashboard Equipment', 'slug' => uniqid('excluded-equipment-'), 'category' => 'other', 'description' => 'Excluded audit scope fixture', 'focus' => 'Excluded', 'status' => 'available', 'is_active' => true]);
        $booking = $this->createBooking($member, $trainer, 1, 'completed');

        $fixtures = [
            ['admin_login', null, null, 'Admin login dashboard real'],
            ['admin_account_updated', User::class, $this->admin->id, 'Akun Admin diperbarui dashboard real'],
            ['transaction_payment_completed', Transaction::class, $transaction->id, 'Pembayaran Membership dashboard real'],
            ['updated', MembershipPlan::class, $plan->id, 'Paket Membership diperbarui dashboard real'],
            ['updated', TrainerProfile::class, $trainer->id, 'Personal Trainer diperbarui dashboard real'],
            ['membership_created', MemberMembership::class, $membership->id, 'Membership dibuat dashboard real'],
            ['updated', Equipment::class, $equipment->id, 'Excluded equipment raw log'],
            ['created', Booking::class, $booking->id, 'Excluded booking raw log'],
            ['transaction_payment_completed', Transaction::class, $ptTransaction->id, 'Excluded PT transaction raw log'],
            ['export_audit', null, null, 'Excluded audit export raw log'],
        ];
        foreach ($fixtures as $index => [$action, $modelType, $modelId, $description]) {
            ActivityLog::create([
                'user_id' => $this->admin->id,
                'action' => $action,
                'model_type' => $modelType,
                'model_id' => $modelId,
                'description' => $description,
                'created_at' => now()->subMinutes(10 - $index),
                'updated_at' => now()->subMinutes(10 - $index),
            ]);
        }

        $response = $this->adminGet(route('admin.dashboard'));
        $response->assertOk()
            ->assertViewHas('recentActivity', fn (array $items) => count($items) === 6
                && collect($items)->pluck('category')->sort()->values()->all() === ['admin_account', 'admin_auth', 'finance', 'membership', 'membership', 'trainer']
                && collect($items)->pluck('type')->unique()->count() >= 4)
            ->assertSeeText('Admin login dashboard real')
            ->assertSeeText('Pembayaran Membership dashboard real')
            ->assertSeeText('Paket Membership diperbarui dashboard real')
            ->assertSeeText('Personal Trainer diperbarui dashboard real')
            ->assertDontSeeText('Excluded equipment raw log')
            ->assertDontSeeText('Excluded booking raw log')
            ->assertDontSeeText('Excluded PT transaction raw log')
            ->assertDontSeeText('Excluded audit export raw log')
            ->assertSee('grid-template-areas: "sales activity" "lower activity";', false)
            ->assertSee('class="dash-panel dash-activity"', false)
            ->assertSee('class="dash-lower"', false)
            ->assertSeeText('View Full Audit Log');

        $audit = $this->adminGet(route('admin.audit-trail.index'));
        $audit->assertOk()
            ->assertSeeText('Pembayaran Membership dashboard real')
            ->assertDontSeeText('Excluded equipment raw log')
            ->assertDontSeeText('Excluded booking raw log');
    }

    public function test_quick_insights_and_pt_trend_combine_paid_child_and_legacy_sessions_without_duplicates(): void
    {
        $memberRole = Role::firstOrCreate(['name' => 'member']);
        $trainerRole = Role::firstOrCreate(['name' => 'trainer']);
        $memberUser = User::create(['role_id' => $memberRole->id, 'name' => 'Insight Member', 'email' => uniqid('insight_member_', true).'@example.test', 'password' => 'password', 'status' => 'active']);
        $member = MemberProfile::create(['user_id' => $memberUser->id, 'member_code' => uniqid('INS-M-')]);
        $trainerAUser = User::create(['role_id' => $trainerRole->id, 'name' => 'Hybrid Top Trainer', 'email' => uniqid('hybrid_a_', true).'@example.test', 'password' => 'password', 'status' => 'active']);
        $trainerBUser = User::create(['role_id' => $trainerRole->id, 'name' => 'Child Only Trainer', 'email' => uniqid('hybrid_b_', true).'@example.test', 'password' => 'password', 'status' => 'active']);
        $trainerA = TrainerProfile::create(['user_id' => $trainerAUser->id, 'specialty' => 'general_fitness', 'price_per_session' => 100000]);
        $trainerB = TrainerProfile::create(['user_id' => $trainerBUser->id, 'specialty' => 'weight_loss', 'price_per_session' => 100000]);

        $legacy = $this->createBooking($member, $trainerA, 10000, 'confirmed');
        $childParent = $this->createBooking($member, $trainerA, 2, 'confirmed');
        $otherParent = $this->createBooking($member, $trainerB, 2, 'confirmed');
        foreach ([[$childParent, $trainerA, 1], [$childParent, $trainerA, 2], [$otherParent, $trainerB, 1], [$otherParent, $trainerB, 2]] as [$parent, $trainer, $sequence]) {
            $scheduleDate = TrainerScheduleDate::firstOrCreate([
                'trainer_profile_id' => $trainer->id,
                'schedule_date' => now()->toDateString(),
            ], [
                'state' => 'open',
                'source' => 'manual',
                'lock_version' => 1,
            ]);
            BookingSessionReservation::create([
                'booking_id' => $parent->id,
                'trainer_profile_id' => $trainer->id,
                'member_profile_id' => $member->id,
                'trainer_schedule_date_id' => $scheduleDate->id,
                'sequence_order' => $sequence,
                'session_date' => now()->toDateString(),
                'start_time' => '10:00:00',
                'end_time' => '11:00:00',
                'session_duration_minutes' => 60,
                'status' => 'reserved',
                'origin' => 'initial_booking',
            ]);
        }

        $plan = $this->createPlan('Real Popular Dashboard Plan');
        foreach (range(1, 30) as $index) {
            Transaction::create(['member_profile_id' => $member->id, 'membership_plan_id' => $plan->id, 'reference_code' => uniqid('INS-TX-'), 'title' => 'Insight sale', 'payment_method' => 'qris', 'amount' => 100000, 'fee' => 1000, 'total_payment' => 101000, 'status' => $index === 1 ? 'completed' : 'paid', 'paid_at' => now()]);
        }
        Equipment::create(['code' => uniqid('LATEST-'), 'name' => 'Newest Real Equipment', 'slug' => uniqid('newest-real-equipment-'), 'category' => 'other', 'description' => 'Newest real equipment insight', 'focus' => 'Dashboard Insight', 'status' => 'available', 'is_active' => true]);

        $response = $this->adminGet(route('admin.dashboard'));
        $insights = $response->viewData('quickInsights');
        $expectedPopularPlanId = Transaction::query()
            ->selectRaw('membership_plan_id, COUNT(*) as total')
            ->whereIn('status', ['completed', 'paid'])
            ->whereNotNull('membership_plan_id')
            ->groupBy('membership_plan_id')
            ->orderByDesc('total')
            ->orderBy('membership_plan_id')
            ->value('membership_plan_id');
        $this->assertSame(
            MembershipPlan::withTrashed()->find($expectedPopularPlanId)?->name ?? 'Belum ada data',
            $insights['popular_plan']
        );
        $this->assertSame('Hybrid Top Trainer', $insights['top_trainer']);
        $this->assertSame('Newest Real Equipment', $insights['latest_equipment']);
        $response->assertOk()
            ->assertViewHas('ptTrend', fn (array $rows) => $rows[0]['name'] === 'Hybrid Top Trainer'
                && $rows[0]['count'] === 10002);
        $this->assertNotNull($legacy->id);
    }

    private function createPlan(string $name): MembershipPlan
    {
        return MembershipPlan::create([
            'name' => $name,
            'slug' => strtolower(str_replace(' ', '-', $name)).'-'.uniqid(),
            'description' => 'Dashboard real data plan',
            'price' => 100000,
            'billing_period' => 'monthly',
            'duration_days' => 30,
            'features_json' => [],
            'is_active' => true,
        ]);
    }

    private function createBooking(MemberProfile $member, TrainerProfile $trainer, int $sessionCount, string $status): Booking
    {
        return Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'session_title' => 'Dashboard hybrid session',
            'session_date' => now()->toDateString(),
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'Studio Dashboard',
            'session_count' => $sessionCount,
            'price_per_session_snapshot' => 100000,
            'total_amount_snapshot' => 100000 * $sessionCount,
            'status' => $status,
            'payment_verified_at' => now(),
        ]);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }
}
