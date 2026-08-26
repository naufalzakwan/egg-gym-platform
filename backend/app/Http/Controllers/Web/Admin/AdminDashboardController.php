<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingSessionReservation;
use App\Models\Equipment;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\TrainerProfile;
use App\Services\Admin\AuditTrailQueryService;
use App\Services\Admin\MembershipRevenueService;
use App\Services\Membership\MembershipPlanPopularityService;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Carbon;

class AdminDashboardController extends Controller
{
    public function __construct(
        private readonly MembershipRevenueService $membershipRevenue,
        private readonly AuditTrailQueryService $auditQuery,
        private readonly MembershipPlanPopularityService $planPopularity,
    ) {}

    public function index(): View
    {
        return view('admin.dashboard', [
            'stats' => $this->buildStatCards(),
            'salesTrends' => $this->buildSalesTrends(),
            'recentActivity' => $this->buildRecentActivity(),
            'ptTrend' => $this->buildPtTrend(),
            'quickInsights' => $this->buildQuickInsights(),
            'footer' => $this->buildFooterStats(),
        ]);
    }

    /**
     * Kartu statistik atas: Total Member, Total PT, Booking Hari Ini, dan
     * pendapatan Membership bersih.
     */
    private function buildStatCards(): array
    {
        $now = now();
        $startOfMonth = $now->copy()->startOfMonth();
        $startOfLastMonth = $now->copy()->subMonthNoOverflow()->startOfMonth();
        $endOfLastMonth = $now->copy()->subMonthNoOverflow()->endOfMonth();

        // Member aktif harus punya membership berjalan dan akun yang aktif.
        $activeMemberships = fn () => MemberMembership::query()
            ->currentlyActive()
            ->whereHas('memberProfile.user', fn ($query) => $query->where('status', 'active'));
        $totalActiveMembers = $activeMemberships()
            ->distinct('member_profile_id')->count('member_profile_id');
        $newThisMonth = $activeMemberships()
            ->whereBetween('member_memberships.created_at', [$startOfMonth, $now])
            ->distinct('member_profile_id')->count('member_profile_id');
        $newLastMonth = MemberMembership::query()
            ->where('status', 'active')
            ->where('payment_status', 'paid')
            ->whereHas('memberProfile.user', fn ($query) => $query->where('status', 'active'))
            ->whereBetween('member_memberships.created_at', [$startOfLastMonth, $endOfLastMonth])
            ->distinct('member_profile_id')->count('member_profile_id');
        $memberDelta = $this->percentChange($newThisMonth, $newLastMonth);

        // Total PT aktif + kapasitas (member aktif ditangani / kuota).
        $totalActiveTrainers = TrainerProfile::query()
            ->whereHas('user', fn ($q) => $q->where('status', 'active'))
            ->count();
        $engagedMembers = Booking::query()
            ->whereIn('status', ['payment_verified', 'confirmed', 'pending', 'waiting_payment', 'payment_uploaded', 'rescheduled'])
            ->distinct('member_profile_id')->count('member_profile_id');
        $capacity = $totalActiveTrainers > 0
            ? (int) round(min(100, $engagedMembers / max(1, $totalActiveTrainers * 2) * 100))
            : 0;

        // Child reservation adalah source of truth sesi multi-session. Booking
        // legacy tanpa child tetap dihitung agar data lama tidak hilang/dobel.
        $today = $now->toDateString();
        $reservationCount = BookingSessionReservation::query()
            ->whereDate('session_date', $today)
            ->whereIn('status', [
                BookingSessionReservation::STATUS_RESERVED,
                BookingSessionReservation::STATUS_COMPLETED,
            ])
            ->count();
        $legacyBookingCount = Booking::query()
            ->whereDoesntHave('sessionReservations')
            ->whereDate('session_date', $today)
            ->whereNotIn('status', ['cancelled', 'expired'])
            ->count();
        $bookingToday = $reservationCount + $legacyBookingCount;
        $nextReservation = BookingSessionReservation::query()
            ->whereDate('session_date', $today)
            ->where('status', BookingSessionReservation::STATUS_RESERVED)
            ->whereTime('start_time', '>=', $now->toTimeString())
            ->orderBy('start_time')
            ->first();
        $nextBooking = Booking::query()
            ->whereDoesntHave('sessionReservations')
            ->whereDate('session_date', $today)
            ->whereNotIn('status', ['cancelled', 'expired'])
            ->whereTime('start_time', '>=', $now->toTimeString())
            ->orderBy('start_time')
            ->first();
        $nextStartTime = collect([
            $nextReservation?->start_time,
            $nextBooking?->start_time,
        ])->filter()->sort()->first();
        $nextBookingTime = $nextStartTime
            ? substr((string) $nextStartTime, 0, 5)
            : null;

        $revenueThisMonth = $this->membershipRevenue->netBetween($startOfMonth, $now->copy()->endOfMonth());
        $revenueLastMonth = $this->membershipRevenue->netBetween($startOfLastMonth, $endOfLastMonth);
        $revenueDelta = $this->membershipRevenue->percentChange($revenueThisMonth, $revenueLastMonth);

        return [
            'total_member' => [
                'value' => $totalActiveMembers,
                'delta' => $memberDelta,
                'sub' => ($memberDelta >= 0 ? '+' : '').$memberDelta.'% vs bulan lalu',
            ],
            'total_pt' => [
                'value' => $totalActiveTrainers,
                'sub' => $capacity.'% capacity used',
            ],
            'booking_today' => [
                'value' => $bookingToday,
                'sub' => $nextBookingTime ? 'Next: '.$nextBookingTime : 'Tidak ada sesi berikutnya',
            ],
            'revenue' => [
                'value' => $revenueThisMonth,
                'value_label' => $this->membershipRevenue->formatRupiah($revenueThisMonth),
                'delta' => $revenueDelta,
                'sub' => $this->membershipRevenue->changeLabel($revenueDelta, 'bulan lalu'),
            ],
        ];
    }

    /**
     * Tren penjualan/pendapatan 6 bulan terakhir (bar chart).
     */
    private function buildSalesTrends(): array
    {
        $now = now();
        $monthly = [];

        for ($i = 5; $i >= 0; $i--) {
            $monthStart = $now->copy()->subMonthsNoOverflow($i)->startOfMonth();
            $monthEnd = $monthStart->copy()->endOfMonth();
            $monthly[] = [
                'label' => strtoupper($monthStart->locale('id')->translatedFormat('M')),
                'value' => $this->membershipRevenue->netBetween($monthStart, $monthEnd),
                'is_active' => $i === 0,
            ];
        }

        $weekly = [];
        for ($i = 5; $i >= 0; $i--) {
            $weekStart = $now->copy()->startOfWeek(Carbon::MONDAY)->subWeeks($i);
            $weekEnd = $weekStart->copy()->endOfWeek(Carbon::SUNDAY);
            $weekly[] = [
                'label' => $weekStart->locale('id')->translatedFormat('d M'),
                'value' => $this->membershipRevenue->netBetween($weekStart, $weekEnd),
                'is_active' => $i === 0,
            ];
        }

        return [
            'monthly' => $this->normalizeTrend($monthly),
            'weekly' => $this->normalizeTrend($weekly),
        ];
    }

    /**
     * Aktivitas terbaru dari audit trail (ActivityLog).
     */
    private function buildRecentActivity(): array
    {
        return $this->auditQuery->scoped()
            ->latest()
            ->limit(6)
            ->get()
            ->map(function ($log) {
                $category = AuditTrailController::categoryFor($log);
                $presentation = $this->activityPresentation($log->action, $category);
                $target = AuditTrailController::resolveTarget($log);
                $actor = $log->user?->name ?? 'Sistem';

                return [
                    'id' => $log->id,
                    'type' => $presentation['type'],
                    'icon' => $presentation['icon'],
                    'tone' => $presentation['tone'],
                    'title' => $log->description ?: ucfirst((string) $log->action).' '.class_basename((string) $log->model_type),
                    'meta' => collect([
                        $log->created_at?->locale('id')->diffForHumans(),
                        $actor,
                        $target,
                    ])->filter()->implode(' • '),
                    'category' => $category,
                ];
            })
            ->all();
    }

    /**
     * Ranking trainer berdasarkan jumlah booking (PT Trend).
     */
    private function buildPtTrend(): array
    {
        $rows = $this->trainerSessionTotals()->take(4);
        $trainers = TrainerProfile::query()->with('user')->whereIn('id', $rows->keys())->get()->keyBy('id');
        $max = (int) ($rows->max() ?? 0);

        return $rows->map(function ($total, $trainerId) use ($max, $trainers) {
            $name = $trainers->get($trainerId)?->user?->name ?? 'Trainer';

            return [
                'name' => $name,
                'count' => (int) $total,
                'percent' => $max > 0 ? (int) round($total / $max * 100) : 0,
            ];
        })->values()->all();
    }

    /**
     * Highlight ringkas: paket terpopuler, PT sesi terbanyak, alat aktif.
     */
    private function buildQuickInsights(): array
    {
        $popularPlanId = $this->planPopularity->bestSellerPlanId();
        $popularPlanName = $popularPlanId !== null
            ? \App\Models\MembershipPlan::withTrashed()->find($popularPlanId)?->name
            : null;

        $topTrainerId = $this->trainerSessionTotals(now()->startOfMonth(), now()->endOfMonth())->keys()->first();
        $topTrainer = $topTrainerId ? TrainerProfile::with('user')->find($topTrainerId) : null;

        $latestEquipment = Equipment::query()
            ->latest('created_at')
            ->orderByDesc('id')
            ->first();

        return [
            'popular_plan' => $popularPlanName ?? 'Belum ada data',
            'top_trainer' => $topTrainer?->user?->name ?? 'Belum ada data',
            'latest_equipment' => $latestEquipment?->name ?? 'Belum ada data',
        ];
    }

    /**
     * Metrik ringkas footer: member growth, retention, PT capacity, last update.
     */
    private function buildFooterStats(): array
    {
        $now = now();
        $totalMembers = MemberProfile::query()->count();
        $activeMembers = MemberMembership::query()->currentlyActive()->distinct('member_profile_id')->count('member_profile_id');
        $retention = $totalMembers > 0 ? round($activeMembers / $totalMembers * 100, 1) : 0.0;

        $activeTrainers = TrainerProfile::query()
            ->whereHas('user', fn ($q) => $q->where('status', 'active'))
            ->count();
        $totalTrainers = TrainerProfile::query()->count();

        $newThisMonth = MemberMembership::query()
            ->where('created_at', '>=', $now->copy()->startOfMonth())
            ->distinct('member_profile_id')->count('member_profile_id');
        $growth = $totalMembers > 0 ? round($newThisMonth / $totalMembers * 100, 1) : 0.0;

        return [
            'member_growth' => $growth,
            'retention_rate' => $retention,
            'active_pt' => $activeTrainers,
            'total_pt' => $totalTrainers,
            'last_update' => $now->locale('id')->translatedFormat('d F Y - H:i').' WIB',
        ];
    }

    private function percentChange(float $current, float $previous): float
    {
        if ($previous <= 0) {
            return $current > 0 ? 100.0 : 0.0;
        }

        return round(($current - $previous) / $previous * 100, 1);
    }

    private function normalizeTrend(array $points): array
    {
        $max = (float) collect($points)->max('value');

        return collect($points)->map(function (array $point) use ($max) {
            $value = (float) $point['value'];
            $point['value_label'] = $this->membershipRevenue->formatRupiah($value);
            $point['height_percent'] = $max > 0
                ? (int) round($value / $max * 100)
                : 0;

            return $point;
        })->all();
    }

    private function trainerSessionTotals(?Carbon $from = null, ?Carbon $until = null): \Illuminate\Support\Collection
    {
        $range = $from && $until ? [$from->toDateString(), $until->toDateString()] : null;
        $child = BookingSessionReservation::query()
            ->selectRaw('trainer_profile_id, COUNT(*) as total')
            ->whereNotNull('trainer_profile_id')
            ->whereIn('status', [BookingSessionReservation::STATUS_RESERVED, BookingSessionReservation::STATUS_COMPLETED])
            ->whereHas('booking', fn ($query) => $query
                ->whereNotNull('payment_verified_at')
                ->whereIn('status', ['payment_verified', 'confirmed', 'rescheduled', 'completed']))
            ->when($range, fn ($query) => $query->whereBetween('session_date', $range))
            ->groupBy('trainer_profile_id')
            ->pluck('total', 'trainer_profile_id')
            ->map(fn ($total) => (int) $total);
        $legacy = Booking::query()
            ->selectRaw('trainer_profile_id, COALESCE(SUM(session_count), 0) as total')
            ->whereDoesntHave('sessionReservations')
            ->whereNotNull('trainer_profile_id')
            ->whereNotNull('payment_verified_at')
            ->whereIn('status', ['payment_verified', 'confirmed', 'rescheduled', 'completed'])
            ->when($range, fn ($query) => $query->whereBetween('session_date', $range))
            ->groupBy('trainer_profile_id')
            ->pluck('total', 'trainer_profile_id')
            ->map(fn ($total) => (int) $total);

        return $child->keys()->merge($legacy->keys())->unique()
            ->mapWithKeys(fn ($trainerId) => [$trainerId => ($child[$trainerId] ?? 0) + ($legacy[$trainerId] ?? 0)])
            ->sort(fn ($a, $b) => $b <=> $a);
    }

    private function activityPresentation(?string $action, string $category): array
    {
        if (in_array($action, ['admin_login', 'admin_logout'], true)) {
            return ['type' => 'session', 'icon' => $action === 'admin_logout' ? '&#10140;' : '&#128100;', 'tone' => 'blue'];
        }
        if (str_contains((string) $action, 'deleted') || str_contains((string) $action, 'deactivated')) {
            return ['type' => 'delete', 'icon' => '&#128465;', 'tone' => 'red'];
        }
        if ($category === 'finance') {
            return ['type' => 'payment', 'icon' => '&#128179;', 'tone' => 'yellow'];
        }
        if (str_contains((string) $action, 'created')) {
            return ['type' => 'create', 'icon' => '&#43;', 'tone' => 'green'];
        }
        if (str_contains((string) $action, 'updated')) {
            return ['type' => 'update', 'icon' => '&#9998;', 'tone' => 'amber'];
        }
        if ($category === 'membership') {
            return ['type' => 'membership', 'icon' => '&#9733;', 'tone' => 'yellow'];
        }
        if ($category === 'trainer') {
            return ['type' => 'trainer', 'icon' => '&#128100;', 'tone' => 'cyan'];
        }

        return ['type' => 'admin', 'icon' => '&#128101;', 'tone' => 'blue'];
    }
}
