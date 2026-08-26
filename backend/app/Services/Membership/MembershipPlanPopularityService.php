<?php

namespace App\Services\Membership;

use App\Models\Transaction;

class MembershipPlanPopularityService
{
    public const SUCCESS_STATUSES = ['completed', 'paid'];

    public function bestSellerPlanId(?callable $planScope = null): ?int
    {
        $query = Transaction::query()
            ->selectRaw(
                'membership_plan_id, COUNT(*) as purchases_count, '
                .'SUM(amount) as total_revenue, MAX(COALESCE(paid_at, created_at)) as latest_purchase_at'
            )
            ->whereIn('status', self::SUCCESS_STATUSES)
            ->whereNotNull('membership_plan_id')
            ->whereHas('membershipPlan', function ($query) use ($planScope) {
                if ($planScope !== null) {
                    $planScope($query);
                }
            })
            ->groupBy('membership_plan_id')
            ->orderByDesc('purchases_count')
            ->orderByDesc('total_revenue')
            ->orderByDesc('latest_purchase_at')
            ->orderBy('membership_plan_id')
            ->first();

        return $query?->membership_plan_id !== null
            ? (int) $query->membership_plan_id
            : null;
    }
}
