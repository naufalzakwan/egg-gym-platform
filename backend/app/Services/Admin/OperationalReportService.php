<?php

namespace App\Services\Admin;

use App\Models\Booking;
use App\Models\MemberMembership;
use App\Models\TrainerProfile;
use App\Models\TrainerRating;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class OperationalReportService
{
    private const PAID_BOOKING_STATUSES = ['payment_verified', 'confirmed', 'rescheduled', 'completed'];

    private const COLORS = ['#F5C300', '#3B82F6', '#4CAF50', '#EF4444', '#8B5CF6', '#06B6D4', '#F97316'];

    public function __construct(
        private readonly MembershipRevenueService $membershipRevenue,
    ) {}

    public function build(string $search = ''): array
    {
        $now = now(config('app.timezone'));
        $revenue = $this->revenue($now);
        $members = $this->members($now);

        return [
            'kpi' => [
                'revenue' => $this->membershipRevenue->formatRupiah($revenue['annual']),
                'revenue_value' => $revenue['annual'],
                'revenue_delta' => $revenue['delta'],
                'revenue_delta_label' => $revenue['delta'] === null
                    ? 'Belum ada data tahun lalu'
                    : $this->membershipRevenue->changeLabel($revenue['delta'], 'tahun lalu'),
                'revenue_period_label' => $revenue['period_label'],
                'revenue_short_period_label' => $revenue['short_period_label'],
                'active_members' => $members['active_count'],
                'new_members' => $members['new_count'],
                'successful_transactions' => $revenue['successful_count'],
                'successful_period_label' => $revenue['period_label'],
            ],
            'revenueTrend' => $revenue['months'],
            'packageDistribution' => $members['distribution'],
            'ptRanking' => $this->ptRanking($search),
        ];
    }

    private function revenue(Carbon $now): array
    {
        $months = [];
        $max = 0.0;
        for ($month = 1; $month <= $now->month; $month++) {
            $start = $now->copy()->month($month)->startOfMonth();
            $value = $this->membershipRevenue->netBetween($start, $start->copy()->endOfMonth());
            $max = max($max, $value);
            $months[] = [
                'label' => strtoupper($start->locale('id')->translatedFormat('M')),
                'full_label' => $start->locale('id')->translatedFormat('F Y'),
                'value' => $value,
                'value_label' => $this->membershipRevenue->formatRupiah($value),
            ];
        }
        $annual = (float) collect($months)->sum('value');
        $yearToDate = $this->membershipRevenue->summaryBetween(
            $now->copy()->startOfYear(),
            $now->copy()->endOfMonth()
        );
        $previous = $this->membershipRevenue->netBetween(
            $now->copy()->subYear()->startOfYear(),
            $now->copy()->subYear()->endOfYear()
        );
        foreach ($months as &$item) {
            $item['height'] = $max > 0 ? (int) round($item['value'] / $max * 100) : 0;
            $item['is_active'] = $max > 0 && $item['value'] === $max;
        }

        return [
            'annual' => $annual,
            'delta' => $this->membershipRevenue->percentChange($annual, $previous),
            'successful_count' => $yearToDate['successful_count'],
            'period_label' => $now->copy()->startOfYear()->locale('id')->translatedFormat('F')
                .'–'.$now->locale('id')->translatedFormat('F Y'),
            'short_period_label' => $now->copy()->startOfYear()->locale('id')->translatedFormat('M')
                .'–'.$now->locale('id')->translatedFormat('M Y'),
            'months' => $months,
        ];
    }

    private function members(Carbon $now): array
    {
        $activeMemberships = MemberMembership::query()
            ->currentlyActive()
            ->with('membershipPlan')
            ->orderByDesc('start_date')
            ->orderByDesc('id')
            ->get()
            ->unique('member_profile_id')
            ->values();
        $firstPaidStarts = MemberMembership::query()
            ->where('payment_status', 'paid')
            ->whereIn('member_profile_id', $activeMemberships->pluck('member_profile_id'))
            ->select('member_profile_id', DB::raw('MIN(start_date) AS first_start_date'))
            ->groupBy('member_profile_id')
            ->get();
        $newCount = $firstPaidStarts->filter(fn ($row) => Carbon::parse($row->first_start_date)->betweenIncluded(
            $now->copy()->startOfMonth()->startOfDay(),
            $now->copy()->endOfMonth()->endOfDay()
        ))->count();
        $grouped = $activeMemberships->groupBy('membership_plan_id')
            ->sortByDesc(fn (Collection $memberships) => $memberships->count());
        $total = $grouped->sum(fn (Collection $memberships) => $memberships->count());
        $segments = $grouped->values()->map(function (Collection $memberships, int $index) use ($total) {
            $count = $memberships->count();

            return [
                'name' => $memberships->first()?->membershipPlan?->name,
                'count' => $count,
                'percent' => $total > 0 ? round($count / $total * 100, 1) : 0,
                'color' => self::COLORS[$index % count(self::COLORS)],
            ];
        })->filter(fn (array $segment) => $segment['name'] !== null && $segment['count'] > 0)->values()->all();

        return [
            'active_count' => $activeMemberships->count(),
            'new_count' => $newCount,
            'distribution' => ['total' => $total, 'segments' => $segments],
        ];
    }

    private function ptRanking(string $search): array
    {
        $paidBookings = Booking::query()
            ->select('trainer_profile_id')
            ->selectRaw('COALESCE(SUM(session_count), 0) AS total_sessions')
            ->selectRaw('COALESCE(SUM(COALESCE(total_amount_snapshot, price_per_session_snapshot * session_count)), 0) AS paid_revenue')
            ->whereNotNull('payment_verified_at')
            ->whereIn('status', self::PAID_BOOKING_STATUSES)
            ->groupBy('trainer_profile_id');
        $ratings = TrainerRating::query()
            ->valid()
            ->select('trainer_profile_id', DB::raw('AVG(rating) AS rating_average'), DB::raw('COUNT(*) AS rating_count'))
            ->groupBy('trainer_profile_id');

        return TrainerProfile::query()
            ->with('user')
            ->leftJoinSub($paidBookings, 'paid_booking_stats', 'paid_booking_stats.trainer_profile_id', '=', 'trainer_profiles.id')
            ->leftJoinSub($ratings, 'rating_stats', 'rating_stats.trainer_profile_id', '=', 'trainer_profiles.id')
            ->when($search !== '', function (Builder $query) use ($search) {
                $query->where(function (Builder $inner) use ($search) {
                    $inner->where('trainer_profiles.specialty', 'like', "%{$search}%")
                        ->orWhere('trainer_profiles.specialties', 'like', "%{$search}%")
                        ->orWhereHas('user', fn (Builder $user) => $user
                            ->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%"));
                });
            })
            ->select('trainer_profiles.*')
            ->selectRaw('COALESCE(paid_booking_stats.total_sessions, 0) AS total_sessions')
            ->selectRaw('COALESCE(paid_booking_stats.paid_revenue, 0) AS paid_revenue')
            ->selectRaw('rating_stats.rating_average, COALESCE(rating_stats.rating_count, 0) AS rating_count')
            ->orderByDesc('total_sessions')
            ->orderByDesc('rating_average')
            ->orderByDesc('paid_revenue')
            ->orderBy('trainer_profiles.id')
            ->get()
            ->map(fn (TrainerProfile $trainer) => [
                'id' => $trainer->id,
                'name' => $trainer->user?->name,
                'specialty' => collect($trainer->specialty_labels)->join(', '),
                'total_sessions' => (int) $trainer->total_sessions,
                'revenue_value' => (float) $trainer->paid_revenue,
                'revenue' => $this->membershipRevenue->formatRupiah((float) $trainer->paid_revenue),
                'rating' => $trainer->rating_average !== null ? round((float) $trainer->rating_average, 2) : null,
                'rating_count' => (int) $trainer->rating_count,
            ])->values()->all();
    }
}
