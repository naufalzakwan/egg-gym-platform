<?php

namespace App\Services\Admin;

use App\Models\Transaction;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class MembershipRevenueService
{
    public const SUCCESS_STATUSES = ['completed', 'paid'];

    public function summaryBetween(CarbonInterface $start, CarbonInterface $end): array
    {
        $successful = Transaction::query()
            ->whereNotNull('membership_plan_id')
            ->whereBetween('paid_at', [$start, $end]);

        return $this->summarizeSuccessfulQuery($successful);
    }

    public function summarizeSuccessfulQuery(Builder $successful): array
    {
        $successful->whereIn('status', self::SUCCESS_STATUSES);
        $known = (clone $successful)->whereNotNull('fee')->whereNotNull('total_payment');

        $net = (float) (clone $known)->sum(DB::raw('total_payment - fee'));
        $knownCount = (clone $known)->count();

        return [
            'net' => $net,
            'average_net' => $knownCount > 0 ? $net / $knownCount : 0.0,
            'successful_count' => (clone $successful)->count(),
            'successful_member_count' => (clone $successful)->distinct()->count('member_profile_id'),
            'known_count' => $knownCount,
            'unknown_count' => (clone $successful)
                ->where(fn (Builder $query) => $query->whereNull('fee')->orWhereNull('total_payment'))
                ->count(),
        ];
    }

    public function netBetween(CarbonInterface $start, CarbonInterface $end): float
    {
        return $this->summaryBetween($start, $end)['net'];
    }

    public function netAmount(Transaction $transaction): ?float
    {
        return $transaction->fee !== null && $transaction->total_payment !== null
            ? (float) $transaction->total_payment - (float) $transaction->fee
            : null;
    }

    public function percentChange(float $current, float $previous): ?float
    {
        return $previous > 0 ? round(($current - $previous) / $previous * 100, 1) : null;
    }

    public function formatRupiah(float $value): string
    {
        return 'Rp '.number_format($value, 0, ',', '.');
    }

    public function changeLabel(?float $change, string $periodLabel): string
    {
        return $change === null
            ? 'Belum ada pembanding '.$periodLabel
            : ($change >= 0 ? '+' : '').number_format($change, 1, ',', '.').'% vs '.$periodLabel;
    }
}
