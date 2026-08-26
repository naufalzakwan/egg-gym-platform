<?php

namespace App\Services\Admin;

use App\Models\Booking;
use App\Models\TrainerProfile;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class TrainerRevenueService
{
    public function __construct(private MembershipRevenueService $formatter) {}

    public function sixMonthSummary(TrainerProfile $trainer, ?CarbonImmutable $now = null): array
    {
        $now ??= CarbonImmutable::now('Asia/Jakarta');
        $firstMonth = $now->startOfMonth()->subMonths(5);
        $lastMonth = $now->endOfMonth();
        $verifiedDate = 'COALESCE(bookings.payment_verified_at, bookings.updated_at)';
        $sessionCount = 'COALESCE(NULLIF(bookings.session_count, 0), reservation_counts.reservation_count, 1)';
        $amount = "COALESCE(bookings.total_amount_snapshot, bookings.price_per_session_snapshot * {$sessionCount}, ? * {$sessionCount})";

        $reservationCounts = DB::table('booking_session_reservations')
            ->select('booking_id')
            ->selectRaw('COUNT(*) AS reservation_count')
            ->groupBy('booking_id');

        $rows = Booking::query()
            ->leftJoinSub($reservationCounts, 'reservation_counts', 'reservation_counts.booking_id', '=', 'bookings.id')
            ->where('bookings.trainer_profile_id', $trainer->id)
            ->where(function ($query) {
                $query
                    ->whereIn('bookings.status', ['payment_verified', 'confirmed', 'completed'])
                    ->orWhere(function ($rescheduled) {
                        $rescheduled
                            ->where('bookings.status', 'rescheduled')
                            ->whereNotNull('bookings.payment_verified_at');
                    });
            })
            ->whereBetween(DB::raw($verifiedDate), [$firstMonth->startOfDay(), $lastMonth->endOfDay()])
            ->selectRaw("DATE_FORMAT({$verifiedDate}, '%Y-%m') AS revenue_month")
            ->selectRaw('COUNT(bookings.id) AS valid_bookings')
            ->selectRaw("COALESCE(SUM({$sessionCount}), 0) AS sold_sessions")
            ->selectRaw("COALESCE(SUM({$amount}), 0) AS revenue", [(float) ($trainer->price_per_session ?? 0)])
            ->groupByRaw("DATE_FORMAT({$verifiedDate}, '%Y-%m')")
            ->get()
            ->keyBy('revenue_month');

        $months = collect(range(0, 5))->map(function (int $offset) use ($now, $rows) {
            $month = $now->startOfMonth()->subMonths($offset);
            $key = $month->format('Y-m');
            $row = $rows->get($key);
            $revenue = (float) ($row?->revenue ?? 0);

            return [
                'key' => $key,
                'label' => $month->locale('id')->translatedFormat('F Y'),
                'revenue_value' => $revenue,
                'revenue_label' => $this->formatter->formatRupiah($revenue),
                'valid_bookings' => (int) ($row?->valid_bookings ?? 0),
                'sold_sessions' => (int) ($row?->sold_sessions ?? 0),
            ];
        })->all();

        return [
            'current' => $months[0],
            'months' => $months,
            'has_revenue' => collect($months)->sum('valid_bookings') > 0,
        ];
    }
}
