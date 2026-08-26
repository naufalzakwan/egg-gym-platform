<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\MemberMembership;
use App\Models\MembershipPlan;
use App\Services\ActivityLogger;
use App\Services\Admin\MembershipRevenueService;
use App\Services\Membership\MembershipPlanPopularityService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class MembershipPlanController extends Controller
{
    public function __construct(
        private readonly MembershipRevenueService $membershipRevenue,
        private readonly MembershipPlanPopularityService $planPopularity,
    ) {}

    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $plans = MembershipPlan::query()
            ->withCount([
                'memberships as active_members_count' => function ($q) {
                    $q->currentlyActive();
                },
            ])
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($inner) use ($search) {
                    $inner->where('name', 'like', '%'.$search.'%')
                        ->orWhere('billing_period', 'like', '%'.$search.'%')
                        ->orWhere('duration_days', 'like', '%'.$search.'%')
                        ->orWhere('price', 'like', '%'.$search.'%');

                    $active = $this->searchBoolean($search);
                    if ($active !== null) {
                        $inner->orWhere('is_active', $active);
                    }
                });
            })
            ->orderBy('price')
            ->get();

        return view('admin.membership-plans.index', [
            'plans' => $plans,
            'kpi' => $this->buildKpi(),
            'search' => $search,
        ]);
    }

    private function searchBoolean(string $search): ?int
    {
        $normalized = strtolower($search);
        if (in_array($normalized, ['aktif', 'active', '1'], true)) {
            return 1;
        }
        if (in_array($normalized, ['nonaktif', 'inactive', '0'], true)) {
            return 0;
        }

        return null;
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validatePlan($request);

        $plan = MembershipPlan::create($this->buildPayload($validated));

        ActivityLogger::logCreated($plan, "Paket membership baru ditambahkan: {$plan->name}");

        return redirect()
            ->route('admin.membership-plans.index')
            ->with('success', 'Paket membership berhasil ditambahkan.');
    }

    public function update(Request $request, MembershipPlan $membershipPlan): RedirectResponse
    {
        $validated = $this->validatePlan($request, $membershipPlan->id);
        $oldData = $membershipPlan->toArray();

        $membershipPlan->update($this->buildPayload($validated));

        ActivityLogger::logUpdated($membershipPlan, $oldData, "Paket membership diperbarui: {$membershipPlan->name}");

        return redirect()
            ->route('admin.membership-plans.index')
            ->with('success', 'Paket membership berhasil diperbarui.');
    }

    public function destroy(MembershipPlan $membershipPlan): RedirectResponse
    {
        $name = $membershipPlan->name;

        // Semua paket diperlakukan sama. Soft delete menghentikan penjualan baru,
        // tetapi foreign key membership/transaksi dan histori lama tetap utuh.
        $membershipPlan->update(['is_active' => false]);
        $membershipPlan->delete();

        ActivityLogger::logDeleted($membershipPlan, "Paket membership dinonaktifkan (soft delete): {$name}");

        return redirect()
            ->route('admin.membership-plans.index')
            ->with('success', "Paket '{$name}' berhasil dinonaktifkan.");
    }

    /**
     * KPI ringkasan halaman paket (data nyata).
     */
    private function buildKpi(): array
    {
        $now = now();

        $totalActive = MembershipPlan::query()->availableForPurchase()->count();

        // Revenue membership bersih dan delta memakai source bersama Admin.
        $currentRevenue = $this->membershipRevenue->summaryBetween($now->copy()->startOfMonth(), $now->copy()->endOfMonth());
        $lastRevenue = $this->membershipRevenue->summaryBetween(
            $now->copy()->subMonthNoOverflow()->startOfMonth(),
            $now->copy()->subMonthNoOverflow()->endOfMonth()
        );
        $revenueThisMonth = $currentRevenue['net'];
        $revenueDelta = $this->membershipRevenue->percentChange($revenueThisMonth, $lastRevenue['net']);

        // Rata-rata masa aktif dari membership valid (active + paid), termasuk
        // histori yang periodenya sudah lewat, berdasarkan tanggal real.
        $averageActiveDays = (int) round((float) MemberMembership::query()
            ->where('status', 'active')
            ->where('payment_status', 'paid')
            ->whereNotNull('start_date')
            ->whereNotNull('end_date')
            ->get()
            ->avg(fn ($m) => $m->start_date && $m->end_date ? $m->start_date->diffInDays($m->end_date) : 0));

        $popularPlanId = $this->planPopularity->bestSellerPlanId();
        $popularPlanName = $popularPlanId !== null
            ? MembershipPlan::withTrashed()->find($popularPlanId)?->name
            : null;

        return [
            'total_active' => $totalActive,
            'revenue_this_month' => $revenueThisMonth,
            'revenue_label' => $currentRevenue['successful_count'] > 0 && $currentRevenue['known_count'] === 0
                ? 'Belum tersedia'
                : $this->membershipRevenue->formatRupiah($revenueThisMonth),
            'revenue_delta' => $revenueDelta,
            'revenue_delta_label' => $this->membershipRevenue->changeLabel($revenueDelta, 'bulan lalu'),
            'revenue_unknown_count' => $currentRevenue['unknown_count'],
            'average_active_days' => $averageActiveDays,
            'average_active_label' => $averageActiveDays.' hari',
            'popular_plan' => $popularPlanName ?? 'Belum ada data',
        ];
    }

    private function validatePlan(Request $request, ?int $planId = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:100', Rule::unique('membership_plans', 'name')->ignore($planId)],
            'price' => ['required', 'numeric', 'min:1'],
            'duration_days' => ['required', 'integer', 'min:1'],
            'release_date' => ['nullable', 'date', 'after:today'],
            'billing_period' => ['nullable', 'string', 'max:30'],
            'features_text' => ['required', 'string'],
            'is_active' => ['nullable', 'boolean'],
        ], [
            'name.unique' => 'Nama paket sudah dipakai paket lain.',
            'price.min' => 'Harga harus lebih dari 0.',
            'duration_days.min' => 'Durasi harus lebih dari 0 hari.',
            'features_text.required' => 'Minimal 1 benefit wajib diisi.',
            'release_date.after' => 'Tanggal rilis harus lebih besar dari hari ini.',
        ]);
    }

    private function buildPayload(array $validated): array
    {
        $name = trim((string) $validated['name']);
        $durationDays = (int) $validated['duration_days'];

        return [
            'name' => $name,
            'slug' => Str::slug($name),
            'description' => null,
            'price' => (float) $validated['price'],
            'duration_days' => $durationDays,
            'release_date' => $validated['release_date'] ?? null,
            'billing_period' => trim((string) ($validated['billing_period'] ?? $this->resolveBillingPeriod($durationDays))),
            'features_json' => $this->parseTextareaLines($validated['features_text'] ?? null),
            // Scheduled package selalu enabled secara internal agar auto-launch
            // bekerja pada tanggal rilis. Effective status tetap UPCOMING sebelum itu.
            'is_active' => ! empty($validated['release_date'])
                ? true
                : (bool) ($validated['is_active'] ?? false),
        ];
    }

    private function resolveBillingPeriod(int $days): string
    {
        return $days >= 360 ? 'yearly' : 'monthly';
    }

    private function parseTextareaLines(?string $value): array
    {
        if ($value === null) {
            return [];
        }

        return collect(preg_split('/\r\n|\r|\n/', $value) ?: [])
            ->map(fn ($line) => trim((string) $line))
            ->filter()
            ->values()
            ->all();
    }
}
