<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\MemberProfile;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;

class MemberPhysicalProgressMonitorController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $checkpoint = in_array($request->query('checkpoint'), ['tracked', 'untracked'], true)
            ? (string) $request->query('checkpoint')
            : '';
        $membership = in_array($request->query('membership'), ['active', 'inactive'], true)
            ? (string) $request->query('membership')
            : '';

        $members = MemberProfile::query()
            ->withCount('progressRecords')
            ->with([
                'user',
                'memberships' => function ($query) {
                    $query->with('membershipPlan')->latest('end_date');
                },
                // PRIVASI: hanya ambil kolom berat/tinggi/tanggal. Kolom `note`
                // dan relasi `photos` SENGAJA TIDAK di-load supaya data sensitif
                // member (catatan & foto) tidak pernah masuk ke response admin.
                'progressRecords' => function ($query) {
                    $query->select(['id', 'member_profile_id', 'weight_kg', 'height_cm', 'recorded_at'])
                        ->orderBy('recorded_at')
                        ->orderBy('id');
                },
            ])
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('member_code', 'like', '%'.$search.'%')
                        ->orWhere('fitness_goal', 'like', '%'.$search.'%')
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%'.$search.'%')
                                ->orWhere('email', 'like', '%'.$search.'%')
                                ->orWhere('phone', 'like', '%'.$search.'%');
                        });
                });
            })
            ->when($checkpoint === 'tracked', fn ($query) => $query->whereHas('progressRecords'))
            ->when($checkpoint === 'untracked', fn ($query) => $query->whereDoesntHave('progressRecords'))
            ->when($membership === 'active', fn ($query) => $query
                ->whereHas('memberships', fn ($membershipQuery) => $membershipQuery->currentlyActive()))
            ->when($membership === 'inactive', fn ($query) => $query
                ->whereDoesntHave('memberships', fn ($membershipQuery) => $membershipQuery->currentlyActive()))
            ->orderByDesc('progress_records_count')
            ->orderBy(
                \App\Models\User::query()
                    ->select('name')
                    ->whereColumn('users.id', 'member_profiles.user_id')
                    ->limit(1)
            )
            ->paginate(5)
            ->withQueryString();

        // Bangun view-model per member (hanya angka, tanpa foto/catatan).
        $rows = $members->getCollection()->map(function (MemberProfile $member) {
            $records = $member->progressRecords; // sudah urut ascending by recorded_at
            $baseline = $records->first();
            $latest = $records->last();
            $checkpointCount = $records->count();
            $hasCheckpoint = $checkpointCount > 0;

            $baselineWeight = $baseline?->weight_kg !== null ? (float) $baseline->weight_kg : null;
            $latestWeight = $latest?->weight_kg !== null ? (float) $latest->weight_kg : null;
            $change = ($baselineWeight !== null && $latestWeight !== null)
                ? round($latestWeight - $baselineWeight, 1)
                : null;

            $activeMembership = $member->memberships->first(fn ($m) => $m->isCurrentlyActive());
            $goal = strtolower((string) $member->fitness_goal);

            // Warna Perubahan BB mengikuti goal member:
            // - goal turun BB  -> penurunan (change < 0) = hijau/baik
            // - goal naik BB   -> kenaikan (change > 0)  = hijau/baik
            $isLoseGoal = str_contains($goal, 'turun') || str_contains($goal, 'lose') || str_contains($goal, 'cut') || str_contains($goal, 'diet');
            $isGainGoal = str_contains($goal, 'naik') || str_contains($goal, 'gain') || str_contains($goal, 'bulk') || str_contains($goal, 'massa');

            $changeColor = 'neutral';
            if ($change !== null && $change != 0) {
                if ($isLoseGoal) {
                    $changeColor = $change < 0 ? 'good' : 'bad';
                } elseif ($isGainGoal) {
                    $changeColor = $change > 0 ? 'good' : 'bad';
                }
            }

            // Tier dari paket aktif untuk badge (Elite/VIP/Standard).
            $planName = strtolower((string) $activeMembership?->membershipPlan?->name);
            if (str_contains($planName, 'elite')) {
                $tier = ['label' => 'Elite', 'cls' => 'elite'];
            } elseif (str_contains($planName, 'annual') || str_contains($planName, 'pro') || str_contains($planName, 'vip')) {
                $tier = ['label' => 'VIP', 'cls' => 'vip'];
            } elseif ($activeMembership) {
                $tier = ['label' => 'Standard', 'cls' => 'standard'];
            } else {
                $tier = ['label' => 'Basic', 'cls' => 'standard'];
            }

            return (object) [
                'name' => $member->user?->name ?? 'Member',
                // Foto profil (avatar) member -> BOLEH tampil di admin. Ini
                // BEDA dari foto/catatan progress fisik (tetap tidak di-load).
                'avatar_url' => $member->user?->avatar_url,
                'member_code' => $member->member_code,
                'goal' => $member->fitness_goal,
                'tier_label' => $tier['label'],
                'tier_cls' => $tier['cls'],
                'plan_name' => $activeMembership?->membershipPlan?->name,
                'plan_end' => $activeMembership?->end_date,
                'has_checkpoint' => $hasCheckpoint,
                'baseline_weight' => $baselineWeight,
                'latest_weight' => $latestWeight,
                'change' => $change,
                'change_color' => $changeColor,
                'checkpoint_count' => $checkpointCount,
                'checkpoint_target' => max($checkpointCount, 6), // target minimal 6 checkpoint
            ];
        });

        return view('admin.member-progress.index', [
            'members' => $members,
            'rows' => $rows,
            'search' => $search,
            'checkpointFilter' => $checkpoint,
            'membershipFilter' => $membership,
            'summary' => $this->buildSummary(),
        ]);
    }

    /**
     * Ringkasan untuk stat cards (data nyata).
     */
    private function buildSummary(): array
    {
        // Rata-rata perubahan BB (baseline -> latest) dari member yang punya
        // minimal 2 checkpoint.
        $changes = MemberProfile::query()
            ->whereHas('progressRecords')
            ->with(['progressRecords' => fn ($q) => $q->select(['id', 'member_profile_id', 'weight_kg', 'recorded_at'])->orderBy('recorded_at')->orderBy('id')])
            ->get()
            ->map(function (MemberProfile $m) {
                $recs = $m->progressRecords;
                if ($recs->count() < 2) {
                    return null;
                }
                $first = $recs->first()->weight_kg;
                $last = $recs->last()->weight_kg;
                if ($first === null || $last === null) {
                    return null;
                }

                return (float) $last - (float) $first;
            })
            ->filter(fn ($v) => $v !== null)
            ->values();

        $avgChange = $changes->count() > 0 ? round($changes->avg(), 1) : 0.0;

        return [
            'total_tracked' => MemberProfile::query()->whereHas('progressRecords')->count(),
            'avg_change' => $avgChange,
            // "Perlu perhatian": member aktif yang BELUM punya checkpoint sama sekali.
            'need_attention' => MemberProfile::query()
                ->whereHas('memberships', fn ($q) => $q->currentlyActive())
                ->whereDoesntHave('progressRecords')
                ->count(),
        ];
    }
}
