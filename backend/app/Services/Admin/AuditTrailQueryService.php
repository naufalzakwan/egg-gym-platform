<?php

namespace App\Services\Admin;

use App\Models\ActivityLog;
use App\Models\MemberMembership;
use App\Models\MembershipPlan;
use App\Models\TrainerProfile;
use App\Models\Transaction;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

class AuditTrailQueryService
{
    private const ADMIN_AUTH_ACTIONS = ['admin_login', 'admin_logout'];

    private const ADMIN_ACCOUNT_ACTIONS = [
        'admin_account_created', 'admin_account_updated',
        'admin_account_activated', 'admin_account_deactivated',
    ];

    private const FINANCE_ACTIONS = [
        'transaction_created', 'transaction_status_changed',
        'transaction_payment_completed', 'pakasir_webhook_updated',
        'created', 'updated',
    ];

    private const MEMBERSHIP_ACTIONS = [
        'membership_created', 'membership_renewed', 'created', 'updated', 'deleted',
    ];

    private const TRAINER_ACTIONS = ['created', 'updated', 'deleted'];

    public function scoped(string $category = 'all'): Builder
    {
        return ActivityLog::query()
            ->with('user.role')
            ->where(fn (Builder $query) => $this->applyScope($query, $category));
    }

    public function filtered(Request $request, array $categoryLabels): Builder
    {
        $search = trim((string) $request->query('search', ''));
        $actor = trim((string) $request->query('actor', 'all'));
        $category = array_key_exists($request->query('category', 'all'), $categoryLabels)
            ? $request->query('category', 'all')
            : 'all';
        $date = trim((string) $request->query('date', 'all'));

        return $this->scoped($category)
            ->when($search !== '', function (Builder $query) use ($search) {
                $query->where(function (Builder $inner) use ($search) {
                    $inner->where('description', 'like', "%{$search}%")
                        ->orWhere('action', 'like', "%{$search}%")
                        ->orWhere('model_id', 'like', "%{$search}%")
                        ->orWhere('old_data', 'like', "%{$search}%")
                        ->orWhere('new_data', 'like', "%{$search}%")
                        ->orWhereHas('user', fn (Builder $user) => $user
                            ->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%"))
                        ->orWhere(function (Builder $target) use ($search) {
                            $target->where('model_type', Transaction::class)
                                ->whereIn('model_id', Transaction::query()
                                    ->where('reference_code', 'like', "%{$search}%")
                                    ->orWhereHas('memberProfile.user', fn (Builder $user) => $user->where('name', 'like', "%{$search}%"))
                                    ->orWhereHas('membershipPlan', fn (Builder $plan) => $plan->where('name', 'like', "%{$search}%"))
                                    ->select('id'));
                        })
                        ->orWhere(function (Builder $target) use ($search) {
                            $target->where('model_type', MemberMembership::class)
                                ->whereIn('model_id', MemberMembership::query()
                                    ->whereHas('memberProfile.user', fn (Builder $user) => $user->where('name', 'like', "%{$search}%"))
                                    ->orWhereHas('membershipPlan', fn (Builder $plan) => $plan->where('name', 'like', "%{$search}%"))
                                    ->select('id'));
                        })
                        ->orWhere(function (Builder $target) use ($search) {
                            $target->where('model_type', TrainerProfile::class)
                                ->whereIn('model_id', TrainerProfile::query()
                                    ->whereHas('user', fn (Builder $user) => $user
                                        ->where('name', 'like', "%{$search}%")
                                        ->orWhere('email', 'like', "%{$search}%"))
                                    ->select('id'));
                        });
                });
            })
            ->when($actor === 'admin', fn (Builder $query) => $query->whereHas('user.role', fn (Builder $role) => $role->where('name', 'admin')))
            ->when($actor === 'member', fn (Builder $query) => $query->whereHas('user.role', fn (Builder $role) => $role->where('name', 'member')))
            ->when($actor === 'trainer', fn (Builder $query) => $query->whereHas('user.role', fn (Builder $role) => $role->where('name', 'trainer')))
            ->when($actor === 'system', fn (Builder $query) => $query->whereNull('user_id'))
            ->when($date === 'today', fn (Builder $query) => $query->whereBetween('created_at', [now()->startOfDay(), now()->endOfDay()]))
            ->when($date === 'week', fn (Builder $query) => $query->whereBetween('created_at', [now()->startOfWeek(), now()->endOfWeek()]))
            ->when($date === 'month', fn (Builder $query) => $query->whereBetween('created_at', [now()->startOfMonth(), now()->endOfMonth()]));
    }

    private function applyScope(Builder $query, string $category): void
    {
        if ($category === 'all' || $category === 'admin_auth') {
            $query->orWhereIn('action', self::ADMIN_AUTH_ACTIONS);
        }
        if ($category === 'all' || $category === 'admin_account') {
            $query->orWhereIn('action', self::ADMIN_ACCOUNT_ACTIONS);
        }
        if ($category === 'all' || $category === 'finance') {
            $query->orWhere(fn (Builder $inner) => $inner
                ->where('model_type', Transaction::class)
                ->whereIn('model_id', Transaction::query()->whereNotNull('membership_plan_id')->select('id'))
                ->whereIn('action', self::FINANCE_ACTIONS));
        }
        if ($category === 'all' || $category === 'membership') {
            $query->orWhere(fn (Builder $inner) => $inner
                ->whereIn('model_type', [MemberMembership::class, MembershipPlan::class])
                ->whereIn('action', self::MEMBERSHIP_ACTIONS));
        }
        if ($category === 'all' || $category === 'trainer') {
            $query->orWhere(fn (Builder $inner) => $inner
                ->where('model_type', TrainerProfile::class)
                ->whereIn('action', self::TRAINER_ACTIONS));
        }
    }
}
