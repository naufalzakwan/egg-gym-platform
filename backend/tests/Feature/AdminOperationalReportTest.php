<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use App\Models\TrainerScheduleDate;
use App\Models\Transaction;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AdminOperationalReportTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private MembershipPlan $starter;

    private MembershipPlan $dynamicPlan;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2025-04-20 12:00:00', 'Asia/Jakarta'));
        $this->admin = $this->createUser('admin', 'Operational Report Admin');
        $this->starter = $this->createPlan('Report Starter');
        $this->dynamicPlan = $this->createPlan('New Dynamic Package');
    }

    public function test_report_aggregates_real_membership_revenue_members_sessions_distribution_and_pt_ranking(): void
    {
        $memberA = $this->createMember('Report Member A', 'A');
        $memberB = $this->createMember('Report Member B', 'B');
        $memberC = $this->createMember('Report Member C', 'C');

        $this->createMembership($memberA, $this->starter, '2025-03-01', '2025-04-30');
        $this->createMembership($memberA, $this->starter, '2025-04-15', '2025-05-14');
        $this->createMembership($memberB, $this->dynamicPlan, '2025-04-05', '2025-05-04');
        $this->createMembership($memberC, $this->dynamicPlan, '2025-01-01', '2025-02-01', 'expired');

        $this->createMembershipTransaction($memberA, $this->starter, '2025-01-10', 100000, 5000, 'completed');
        $this->createMembershipTransaction($memberB, $this->dynamicPlan, '2025-04-10', 200000, 10000, 'paid');
        $this->createMembershipTransaction($memberC, $this->starter, '2025-04-11', 9000000, 1000, 'pending');
        $this->createMembershipTransaction($memberC, $this->starter, '2025-04-12', 8000000, 1000, 'failed');
        $this->createMembershipTransaction($memberC, null, '2025-04-13', 7000000, 1000, 'completed');
        $this->createMembershipTransaction($memberA, $this->starter, '2024-03-10', 50000, 2500, 'completed');

        $trainerOne = $this->createTrainer('Trainer One', 5.0);
        $trainerTwo = $this->createTrainer('Trainer Two', 1.0);
        $trainerThree = $this->createTrainer('Trainer Three', 5.0);

        $bookingOne = $this->createPaidBooking($memberA, $trainerOne, 2, 200000, 'completed');
        $this->createReservation($bookingOne, $trainerOne, $memberA, '2025-04-10', 'completed');
        $this->createReservation($bookingOne, $trainerOne, $memberA, '2025-04-11', 'cancelled');
        $this->createReservation($bookingOne, $trainerOne, $memberA, '2025-04-25', 'reserved');

        $pendingParent = $this->createPaidBooking($memberA, $trainerOne, 1, 9900000, 'pending', false);
        $this->createReservation($pendingParent, $trainerOne, $memberA, '2025-04-09', 'completed');

        $legacyTwo = $this->createPaidBooking($memberB, $trainerTwo, 2, 300000, 'completed');
        $cancelledRevenue = $this->createPaidBooking($memberB, $trainerTwo, 3, 900000, 'cancelled');
        $cancelledRevenue->update(['session_date' => '2025-04-25']);
        $pendingRevenue = $this->createPaidBooking($memberB, $trainerTwo, 4, 1200000, 'confirmed', false);
        $this->assertNotNull($legacyTwo->id);
        $this->assertNotNull($cancelledRevenue->id);
        $this->assertNotNull($pendingRevenue->id);

        $this->createRating($memberA, $trainerOne, 4);
        $this->createRating($memberB, $trainerOne, 5);
        $this->createRating($memberA, $trainerTwo, 5);

        $response = $this->adminGet(route('admin.reports.index'));
        $response->assertOk();
        $kpi = $response->viewData('kpi');
        $this->assertSame(300000.0, $kpi['revenue_value']);
        $this->assertSame('Rp 300.000', $kpi['revenue']);
        $this->assertSame('Januari–April 2025', $kpi['revenue_period_label']);
        $this->assertSame('Jan–Apr 2025', $kpi['revenue_short_period_label']);
        $this->assertSame(2, $kpi['active_members']);
        $this->assertSame(1, $kpi['new_members']);
        $this->assertSame(2, $kpi['successful_transactions']);
        $this->assertSame('Januari–April 2025', $kpi['successful_period_label']);
        $revenueTrend = $response->viewData('revenueTrend');
        $this->assertSame(300000.0, (float) collect($revenueTrend)->sum('value'));
        $this->assertSame(200000.0, $revenueTrend[3]['value']);
        $this->assertSame('Rp 200.000', $revenueTrend[3]['value_label']);

        $paymentKpi = $this->adminGet(route('admin.transactions.index', ['date' => 'month']))->viewData('kpi');
        $this->assertSame('Rp 200.000', $paymentKpi['revenue_label']);
        $this->assertSame($paymentKpi['revenue_label'], $revenueTrend[3]['value_label']);
        $response
            ->assertViewHas('revenueTrend', fn (array $months) => count($months) === 4
                && collect($months)->sum('value') === 300000.0
                && $months[0]['value'] === 100000.0
                && $months[3]['value'] === 200000.0)
            ->assertViewHas('packageDistribution', fn (array $distribution) => $distribution['total'] === 2
                && collect($distribution['segments'])->pluck('count', 'name')->all() === [
                    'Report Starter' => 1,
                    'New Dynamic Package' => 1,
                ])
            ->assertSeeText('Analisis Pendapatan')
            ->assertSeeText('Pendapatan Membership per Bulan')
            ->assertSeeText('Distribusi Paket Membership')
            ->assertSeeText('New Dynamic Package')
            ->assertSeeText('Member aktif')
            ->assertSeeText('Peringkat Kinerja Personal Trainer')
            ->assertSeeText('Total Sesi')
            ->assertSeeText('Diurutkan berdasarkan total sesi terbayar, rating, lalu pendapatan PT')
            ->assertDontSeeText('Sesi Selesai')
            ->assertSeeText('Belum ada rating')
            ->assertSeeText('Transaksi Berhasil Tahun Ini')
            ->assertSee('id="report-revenue-chart"', false)
            ->assertSee('data-report-bar="0"', false)
            ->assertSee("bar.addEventListener('click', () => selectBar(bar))", false)
            ->assertSee('tooltip.textContent = bar.dataset.valueLabel;', false)
            ->assertSeeText('Transaksi membership sukses Januari–April 2025')
            ->assertSeeText('4,50 / 5')
            ->assertSeeText('2 ulasan')
            ->assertSeeInOrder([
                'Pendapatan Tahunan',
                'Rp 300.000',
                'Pendapatan bersih Jan–Apr 2025',
            ])
            ->assertDontSeeText('Efisiensi Sesi PT')
            ->assertDontSeeText('Revenue Analytics')
            ->assertDontSeeText('Monthly Performance Projection')
            ->assertDontSeeText('Packages Distribution')
            ->assertDontSeeText('ELITE');
        $ranking = $response->viewData('ptRanking');
        $fixtureRanking = collect($ranking)->whereIn('id', [$trainerOne->id, $trainerTwo->id, $trainerThree->id])->values()->all();
        $this->assertSame([$trainerTwo->id, $trainerOne->id, $trainerThree->id], array_column($fixtureRanking, 'id'));
        $byId = collect($fixtureRanking)->keyBy('id');
        $this->assertSame(2, $byId[$trainerTwo->id]['total_sessions']);
        $this->assertSame(300000.0, $byId[$trainerTwo->id]['revenue_value']);
        $this->assertSame(5.0, $byId[$trainerTwo->id]['rating']);
        $this->assertSame(1, $byId[$trainerTwo->id]['rating_count']);
        $this->assertSame(2, $byId[$trainerOne->id]['total_sessions']);
        $this->assertSame(200000.0, $byId[$trainerOne->id]['revenue_value']);
        $this->assertSame(4.5, $byId[$trainerOne->id]['rating']);
        $this->assertSame(2, $byId[$trainerOne->id]['rating_count']);
        $this->assertSame(0, $byId[$trainerThree->id]['total_sessions']);
        $this->assertSame(0.0, $byId[$trainerThree->id]['revenue_value']);
        $this->assertNull($byId[$trainerThree->id]['rating']);
    }

    public function test_empty_report_uses_real_zero_and_explicit_empty_states(): void
    {
        $response = $this->adminGet(route('admin.reports.index', ['search' => 'trainer-does-not-exist']));
        $response->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue'] === 'Rp 0'
                && $kpi['revenue_delta'] === null
                && $kpi['revenue_delta_label'] === 'Belum ada data tahun lalu'
                && $kpi['active_members'] === 0
                && $kpi['new_members'] === 0)
            ->assertViewHas('packageDistribution', fn (array $distribution) => $distribution['total'] === 0
                && $distribution['segments'] === [])
            ->assertViewHas('ptRanking', [])
            ->assertSeeText('Belum ada distribusi Membership aktif.')
            ->assertSeeText('Tidak ada data yang cocok.');
    }

    public function test_booking_without_verified_payment_is_not_counted(): void
    {
        $member = $this->createMember('Completed Session Member', 'COMPLETED');
        $trainer = $this->createTrainer('Completed Session Trainer', 5.0);

        $modern = $this->createPaidBooking($member, $trainer, 1, 150000, 'completed', false);
        $this->createReservation($modern, $trainer, $member, '2025-04-10', 'completed');
        $legacy = $this->createPaidBooking($member, $trainer, 1, 175000, 'completed', false);

        $response = $this->adminGet(route('admin.reports.index', ['search' => 'Completed Session Trainer']));
        $response->assertOk();

        $trainerRow = collect($response->viewData('ptRanking'))->firstWhere('id', $trainer->id);
        $this->assertNotNull($trainerRow);
        $this->assertSame(0, $trainerRow['total_sessions']);
        $this->assertSame(0.0, $trainerRow['revenue_value']);
        $this->assertSame('Rp 0', $trainerRow['revenue']);
        $this->assertNotNull($legacy->id);
    }

    public function test_total_sessions_and_revenue_use_verified_parent_booking_snapshots_once(): void
    {
        $member = $this->createMember('Paid Session Member', 'PAID');
        $trainer = $this->createTrainer('Paid Session Trainer', 1.0);
        $otherTrainer = $this->createTrainer('Other Paid Trainer', 1.0);
        $twoSessions = $this->createPaidBooking($member, $trainer, 2, 200000, 'payment_verified');
        $threeSessions = $this->createPaidBooking($member, $trainer, 3, 300000, 'completed');

        foreach (range(1, 2) as $sequence) {
            $this->createReservation($twoSessions, $trainer, $member, '2025-03-0'.$sequence, 'reserved');
        }
        foreach (range(1, 3) as $sequence) {
            $this->createReservation($threeSessions, $trainer, $member, '2025-03-1'.$sequence, 'reserved');
        }

        $trainer->update(['price_per_session' => 999000]);
        $this->createPaidBooking($member, $trainer, 4, 400000, 'payment_uploaded', false);
        $this->createPaidBooking($member, $trainer, 5, 500000, 'payment_rejected', false);
        $this->createPaidBooking($member, $trainer, 6, 600000, 'cancelled');
        $this->createPaidBooking($member, $trainer, 7, 700000, 'expired');
        $this->createPaidBooking($member, $trainer, 8, 800000, 'rejected');
        $otherBooking = $this->createPaidBooking($member, $otherTrainer, 4, 400000, 'confirmed');
        foreach (range(1, 4) as $sequence) {
            $this->createReservation($otherBooking, $otherTrainer, $member, '2025-02-0'.$sequence, 'reserved');
        }

        $response = $this->adminGet(route('admin.reports.index'));
        $response->assertOk();
        $fixtureRows = collect($response->viewData('ptRanking'))
            ->whereIn('id', [$trainer->id, $otherTrainer->id])
            ->values();
        $trainerRow = $fixtureRows->firstWhere('id', $trainer->id);
        $otherRow = $fixtureRows->firstWhere('id', $otherTrainer->id);

        $this->assertNotNull($trainerRow);
        $this->assertNotNull($otherRow);
        $this->assertSame([$trainer->id, $otherTrainer->id], $fixtureRows->pluck('id')->all());
        $this->assertSame(5, $trainerRow['total_sessions']);
        $this->assertSame(500000.0, $trainerRow['revenue_value']);
        $this->assertSame('Rp 500.000', $trainerRow['revenue']);
        $this->assertSame(4, $otherRow['total_sessions']);
        $this->assertSame(400000.0, $otherRow['revenue_value']);
        $this->assertSame(5, $twoSessions->sessionReservations()->count() + $threeSessions->sessionReservations()->count());
    }

    private function createUser(string $roleName, string $name): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid(strtolower($roleName).'_report_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function createMember(string $name, string $suffix): MemberProfile
    {
        return MemberProfile::create([
            'user_id' => $this->createUser('member', $name)->id,
            'member_code' => 'REPORT-'.$suffix.'-'.uniqid(),
            'joined_at' => now(),
        ]);
    }

    private function createPlan(string $name): MembershipPlan
    {
        return MembershipPlan::create([
            'name' => $name,
            'slug' => str($name)->slug().'-'.uniqid(),
            'description' => 'Operational report fixture',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
    }

    private function createMembership(
        MemberProfile $member,
        MembershipPlan $plan,
        string $start,
        string $end,
        string $status = 'active'
    ): MemberMembership {
        return MemberMembership::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan->id,
            'start_date' => $start,
            'end_date' => $end,
            'status' => $status,
            'payment_status' => 'paid',
        ]);
    }

    private function createMembershipTransaction(
        MemberProfile $member,
        ?MembershipPlan $plan,
        string $paidAt,
        float $net,
        float $fee,
        string $status
    ): Transaction {
        return Transaction::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $plan?->id,
            'reference_code' => 'REPORT-TX-'.uniqid(),
            'title' => $plan ? 'Membership Payment' : 'PT Payment',
            'payment_method' => 'qris',
            'amount' => $net,
            'fee' => $fee,
            'total_payment' => $net + $fee,
            'status' => $status,
            'paid_at' => $paidAt,
        ]);
    }

    private function createTrainer(string $name, float $cachedRating): TrainerProfile
    {
        return TrainerProfile::create([
            'user_id' => $this->createUser('trainer', $name)->id,
            'specialty' => 'Strength Training',
            'specialties' => ['Strength Training'],
            'tier' => 'pro',
            'max_clients' => 30,
            'verification_status' => 'verified',
            'rating' => $cachedRating,
        ]);
    }

    private function createPaidBooking(
        MemberProfile $member,
        TrainerProfile $trainer,
        int $sessionCount,
        float $total,
        string $status,
        bool $verified = true
    ): Booking {
        return Booking::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'session_title' => 'Report PT Session',
            'session_date' => '2025-04-10',
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'location' => 'EggGym Studio',
            'session_count' => $sessionCount,
            'price_per_session_snapshot' => $total / $sessionCount,
            'total_amount_snapshot' => $total,
            'status' => $status,
            'payment_verified_at' => $verified ? now()->subMonth() : null,
        ]);
    }

    private function createReservation(
        Booking $booking,
        TrainerProfile $trainer,
        MemberProfile $member,
        string $date,
        string $status
    ): BookingSessionReservation {
        $scheduleDate = TrainerScheduleDate::firstOrCreate([
            'trainer_profile_id' => $trainer->id,
            'schedule_date' => $date,
        ], [
            'state' => 'open', 'source' => 'manual', 'template_version' => 1, 'lock_version' => 1,
        ]);

        return BookingSessionReservation::create([
            'booking_id' => $booking->id,
            'sequence_order' => $booking->sessionReservations()->count() + 1,
            'trainer_profile_id' => $trainer->id,
            'member_profile_id' => $member->id,
            'trainer_schedule_date_id' => $scheduleDate->id,
            'session_date' => $date,
            'start_time' => '10:00:00',
            'end_time' => '11:00:00',
            'session_duration_minutes' => 60,
            'status' => $status,
            'completed_at' => $status === 'completed' ? now() : null,
        ]);
    }

    private function createRating(MemberProfile $member, TrainerProfile $trainer, int $rating): TrainerRating
    {
        return TrainerRating::create([
            'member_profile_id' => $member->id,
            'trainer_profile_id' => $trainer->id,
            'rating' => $rating,
            'testimonial' => 'Operational report rating',
        ]);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }
}
