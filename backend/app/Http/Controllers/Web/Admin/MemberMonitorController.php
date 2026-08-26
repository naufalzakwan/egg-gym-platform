<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\User;
use App\Services\ActivityLogger;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class MemberMonitorController extends Controller
{
    public function index(Request $request): View
    {
        $status = $request->query('status', 'all');
        $activePlan = trim((string) $request->query('plan', ''));
        $search = trim((string) $request->query('search'));
        $plans = MembershipPlan::query()->availableForPurchase()->orderBy('name')->get();
        if ($activePlan !== '' && ! $plans->contains('name', $activePlan)) {
            $activePlan = '';
        }

        $query = MemberProfile::query()
            ->with([
                'user',
                'memberships' => function ($query) {
                    $query->with('membershipPlan')
                        ->latest('end_date');
                },
            ])
            ->withCount(['bookings', 'trainingPrograms'])
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('member_code', 'like', '%'.$search.'%')
                        ->orWhere('fitness_goal', 'like', '%'.$search.'%')
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%'.$search.'%')
                                ->orWhere('email', 'like', '%'.$search.'%')
                                ->orWhere('phone', 'like', '%'.$search.'%')
                                ->orWhere('status', 'like', '%'.$search.'%');
                        });
                });
            });

        // Filter status berbasis ada/tidaknya membership yang sedang aktif.
        if ($status === 'active') {
            $query->whereHas('memberships', fn ($q) => $q->currentlyActive());
        } elseif ($status === 'inactive') {
            $query->whereDoesntHave('memberships', fn ($q) => $q->currentlyActive());
        }

        // Filter satu kategori paket aktif, tanpa memisahkan durasi paket.
        if ($activePlan !== '') {
            $query->whereHas('memberships', function ($membershipQuery) use ($activePlan) {
                $membershipQuery->currentlyActive()
                    ->whereHas('membershipPlan', fn ($planQuery) => $planQuery->where('name', $activePlan));
            });
        }

        $members = $query
            ->orderBy(
                User::query()
                    ->select('name')
                    ->whereColumn('users.id', 'member_profiles.user_id')
                    ->limit(1)
            )
            ->paginate(5)
            ->withQueryString();

        return view('admin.members.index', [
            'members' => $members,
            'search' => $search,
            'status' => $status,
            'activePlan' => $activePlan,
            'plans' => $plans,
            'summary' => $this->buildSummary(),
        ]);
    }

    public function create(): View
    {
        return view('admin.members.form', [
            'member' => new MemberProfile,
            'pageTitle' => 'Tambah Member Baru',
            'submitLabel' => 'Tambahkan Member',
            'action' => route('admin.members.store'),
            'method' => 'POST',
            'plans' => MembershipPlan::query()->availableForPurchase()->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validateMember($request);

        $memberRole = Role::query()->where('name', 'member')->first();
        if (! $memberRole) {
            return back()->withInput()->with('error', 'Konfigurasi role member tidak ditemukan.');
        }

        $member = DB::transaction(function () use ($validated, $memberRole) {
            $user = User::create([
                'role_id' => $memberRole->id,
                'name' => trim($validated['name']),
                'email' => trim($validated['email']),
                'phone' => trim((string) ($validated['phone'] ?? '')),
                // Password default bila admin tidak mengisi (member bisa reset nanti).
                'password' => Hash::make($validated['password'] ?? 'member12345'),
                'status' => $validated['status'] ?? 'active',
            ]);

            $member = MemberProfile::create([
                'user_id' => $user->id,
                'member_code' => 'MBR-'.str_pad((string) $user->id, 5, '0', STR_PAD_LEFT),
                'gender' => $validated['gender'] ?? null,
                'birth_date' => $validated['birth_date'] ?? null,
                'height_cm' => $validated['height_cm'] ?? null,
                'weight_kg' => $validated['weight_kg'] ?? null,
                'fitness_goal' => $validated['fitness_goal'] ?? null,
                'joined_at' => now(),
            ]);

            $this->syncMembership($member, $validated);

            return $member;
        });

        ActivityLogger::logCreated($member, "Member baru ditambahkan: {$member->user?->name}");

        return redirect()
            ->route('admin.members.index')
            ->with('success', 'Member berhasil ditambahkan.');
    }

    public function edit(MemberProfile $member): View
    {
        $member->load(['user', 'memberships.membershipPlan']);
        $activeMembership = MemberMembership::activeChainMembership($member->memberships);

        return view('admin.members.manage', [
            'member' => $member,
            'activeMembership' => $activeMembership,
            'activeMembershipEnd' => MemberMembership::activeChainEndDate($member->memberships),
        ]);
    }

    public function update(Request $request, MemberProfile $member): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:active,inactive'],
        ]);
        $user = $member->user;
        if (! $user) {
            return back()->with('error', 'Akun member tidak ditemukan.');
        }

        $oldStatus = $user->status;
        if ($oldStatus !== $validated['status']) {
            $user->update(['status' => $validated['status']]);
            ActivityLogger::logUpdated(
                $member,
                ['status' => $oldStatus],
                "Status akun member diubah menjadi {$validated['status']}: {$user->name}"
            );
        }

        return redirect()
            ->route('admin.members.edit', $member)
            ->with('success', 'Status akun member berhasil disimpan.');
    }

    public function resetPassword(Request $request, MemberProfile $member): RedirectResponse
    {
        $validated = $request->validate([
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'password_reset_confirmation' => ['accepted'],
        ], [
            'password.required' => 'Password baru wajib diisi.',
            'password.min' => 'Password baru minimal 8 karakter.',
            'password.confirmed' => 'Konfirmasi password baru tidak sama.',
            'password_reset_confirmation.accepted' => 'Konfirmasi reset password wajib dicentang.',
        ]);
        $user = $member->user;
        if (! $user) {
            return back()->with('error', 'Akun member tidak ditemukan.');
        }

        $user->update(['password' => Hash::make($validated['password'])]);
        ActivityLogger::log(
            action: 'member_password_reset',
            model: $member,
            description: "Admin mereset password Member: {$user->name} ({$member->member_code})",
        );

        return redirect()
            ->route('admin.members.edit', $member)
            ->with('success', 'Password member berhasil direset.');
    }

    /**
     * Nonaktifkan / aktifkan akun member (soft, tanpa menghapus data).
     */
    public function toggleStatus(MemberProfile $member): RedirectResponse
    {
        $user = $member->user;
        if (! $user) {
            return back()->with('error', 'Akun member tidak ditemukan.');
        }

        $newStatus = $user->status === 'active' ? 'inactive' : 'active';
        $user->update(['status' => $newStatus]);

        ActivityLogger::logUpdated($member, [], "Status member diubah menjadi {$newStatus}: {$user->name}");

        return redirect()
            ->route('admin.members.index')
            ->with('success', 'Status member berhasil diubah menjadi '.($newStatus === 'active' ? 'aktif' : 'nonaktif').'.');
    }

    public function destroy(MemberProfile $member): RedirectResponse
    {
        $member->loadCount(['bookings', 'trainingPrograms']);
        $name = $member->user?->name ?? 'Member';

        // Aman: bila member sudah punya riwayat booking/program, jangan hapus
        // permanen (bisa memutus relasi/riwayat). Nonaktifkan akunnya saja.
        if ($member->bookings_count > 0 || $member->training_programs_count > 0) {
            $member->user?->update(['status' => 'inactive']);

            ActivityLogger::logUpdated($member, [], "Member dinonaktifkan (punya riwayat, tidak dihapus): {$name}");

            return redirect()
                ->route('admin.members.index')
                ->with('success', "Member '{$name}' punya riwayat booking/program, jadi dinonaktifkan (bukan dihapus permanen).");
        }

        ActivityLogger::logDeleted($member, "Member dihapus: {$name}");

        // Hapus user → member_profile ikut terhapus (cascade FK).
        DB::transaction(function () use ($member) {
            $user = $member->user;
            $member->delete();
            $user?->delete();
        });

        return redirect()
            ->route('admin.members.index')
            ->with('success', "Member '{$name}' berhasil dihapus.");
    }

    /**
     * Buat/perpanjang membership bila admin memilih paket + durasi.
     */
    private function syncMembership(MemberProfile $member, array $validated): void
    {
        $planId = $validated['membership_plan_id'] ?? null;
        if (empty($planId)) {
            return;
        }

        $durationMonths = (int) ($validated['duration_months'] ?? 1);
        $startDate = ! empty($validated['start_date'])
            ? \Illuminate\Support\Carbon::parse($validated['start_date'])
            : now();
        $endDate = $startDate->copy()->addMonthsNoOverflow($durationMonths);

        $membership = MemberMembership::create([
            'member_profile_id' => $member->id,
            'membership_plan_id' => $planId,
            'start_date' => $startDate->toDateString(),
            'end_date' => $endDate->toDateString(),
            'status' => 'active',
            'payment_status' => $validated['payment_status'] ?? 'paid',
        ]);
        $membership->load(['memberProfile.user', 'membershipPlan']);
        ActivityLogger::log(
            action: 'membership_created',
            model: $membership,
            newData: [
                'member_profile_id' => $membership->member_profile_id,
                'member_name' => $membership->memberProfile?->user?->name,
                'membership_plan_id' => $membership->membership_plan_id,
                'membership_plan_name' => $membership->membershipPlan?->name,
                'start_date' => $membership->start_date?->toDateString(),
                'end_date' => $membership->end_date?->toDateString(),
                'status' => $membership->status,
                'payment_status' => $membership->payment_status,
                'source' => 'Web Admin',
            ],
            description: 'Membership dibuat oleh Admin: '.($membership->memberProfile?->user?->name ?? "Member #{$membership->member_profile_id}"),
        );
    }

    private function validateMember(Request $request, ?MemberProfile $member = null): array
    {
        $userId = $member?->user_id;

        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($userId)],
            'phone' => ['nullable', 'string', 'max:30'],
            'password' => [$member ? 'nullable' : 'nullable', 'string', 'min:8'],
            'gender' => ['nullable', 'in:male,female'],
            'birth_date' => ['nullable', 'date'],
            'height_cm' => ['nullable', 'numeric', 'min:0', 'max:300'],
            'weight_kg' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'fitness_goal' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', 'in:active,inactive'],
            'membership_plan_id' => ['nullable', 'exists:membership_plans,id'],
            'duration_months' => ['nullable', 'integer', 'min:1', 'max:24'],
            'start_date' => ['nullable', 'date'],
            'payment_status' => ['nullable', 'in:paid,pending,unpaid'],
        ], [
            'email.unique' => 'Email ini sudah digunakan akun lain.',
        ]);
    }

    /**
     * Ringkasan member untuk summary cards (data nyata).
     */
    private function buildSummary(): array
    {
        $now = now();
        $totalMembers = MemberProfile::query()->count();

        // Pertumbuhan member bulan ini vs bulan lalu.
        $newThisMonth = MemberProfile::query()
            ->where('created_at', '>=', $now->copy()->startOfMonth())
            ->count();
        $newLastMonth = MemberProfile::query()
            ->whereBetween('created_at', [
                $now->copy()->subMonthNoOverflow()->startOfMonth(),
                $now->copy()->subMonthNoOverflow()->endOfMonth(),
            ])
            ->count();
        $growth = $newLastMonth > 0
            ? round(($newThisMonth - $newLastMonth) / $newLastMonth * 100, 1)
            : ($newThisMonth > 0 ? 100.0 : 0.0);

        $activeMembers = MemberMembership::query()
            ->currentlyActive()
            ->distinct()
            ->count('member_profile_id');

        // "Berakhir dalam 30 hari" dihitung dari UJUNG RANTAI KONTIGU tiap
        // member (activeChainEndDate), BUKAN end_date row individual. Member
        // seperti dudung (rantai sampai 110 hari) tidak lagi salah masuk kartu
        // ini hanya karena satu row di tengah rantai kebetulan berakhir <=30
        // hari. Sumber tanggal sama dgn kolom list & Flutter -> konsisten.
        // Chain logic ada di PHP, jadi hitung per member (hanya member aktif).
        $threshold = $now->copy()->addDays(30)->endOfDay();

        $expiringSoon = MemberProfile::query()
            ->whereHas('memberships', fn ($q) => $q->currentlyActive())
            ->with(['memberships' => fn ($q) => $q->with('membershipPlan')])
            ->get()
            ->filter(function ($member) use ($threshold) {
                $chainEnd = MemberMembership::activeChainEndDate($member->memberships);

                return $chainEnd !== null
                    && $chainEnd->lessThanOrEqualTo($threshold);
            })
            ->count();

        return [
            'total_members' => $totalMembers,
            'growth_percent' => $growth,
            'active_membership' => $activeMembers,
            'expiring_soon' => $expiringSoon,
        ];
    }
}
