@extends('admin.layouts.app')

@php
    $title = 'Members Admin EggGym';
    $pageHeading = 'Data Member';
    $pageSubheading = 'Pantau data member, membership aktif, dan aktivitas training.';
@endphp

@section('content')
    <style>
        .mbr-filter {
            display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 16px;
        }
        .mbr-tab {
            padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 700;
            border: 1px solid var(--border); background: transparent; color: var(--muted);
            transition: all 0.15s ease;
        }
        .mbr-tab:hover { border-color: var(--accent); color: var(--accent); }
        .mbr-tab.active { background: var(--accent); color: var(--on-accent); border-color: var(--accent); }
        .mbr-filter select {
            height: 38px; width: auto; min-width: 130px;
        }

        .mbr-table-card {
            background: var(--panel); border: 1px solid var(--border);
            border-radius: 10px; overflow: hidden;
        }
        .mbr-grid {
            display: grid;
            grid-template-columns: 2fr 1.8fr 1.5fr 1fr 1.2fr 0.8fr;
            gap: 12px; align-items: center;
        }
        .mbr-thead {
            background: var(--bg); padding: 12px 20px;
            font-size: 10px; font-weight: 700; letter-spacing: 0.1em;
            text-transform: uppercase; color: var(--muted);
        }
        .mbr-row {
            padding: 14px 20px; border-bottom: 1px solid var(--border);
            transition: background 0.15s ease;
        }
        .mbr-row:last-child { border-bottom: 0; }
        .mbr-row:hover { background: rgba(250,204,21,0.03); }

        .mbr-name-cell { display: flex; align-items: center; gap: 10px; }
        .mbr-avatar {
            width: 36px; height: 36px; border-radius: 50%; flex-shrink: 0;
            display: flex; align-items: center; justify-content: center;
            font-size: 14px; font-weight: 700; color: var(--accent);
            background: linear-gradient(135deg, #353534 0%, #131313 100%);
            border: 2px solid var(--border);
        }
        .mbr-name { font-size: 14px; font-weight: 700; color: var(--text); }
        .mbr-id { font-size: 11px; color: var(--text-muted); font-family: "JetBrains Mono", monospace; letter-spacing: 0.3px; }
        .mbr-email { font-size: 13px; color: var(--muted); }
        .mbr-phone { font-size: 12px; color: var(--text-muted); margin-top: 2px; }

        .pill {
            display: inline-flex; align-items: center; padding: 3px 10px; border-radius: 9999px;
            font-size: 11px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase;
        }
        .pill-platinum { background: rgba(250,204,21,0.15); color: #FACC15; }
        .pill-gold { background: rgba(245,158,11,0.15); color: #F59E0B; }
        .pill-pro { background: rgba(59,130,246,0.15); color: #3B82F6; }
        .pill-basic { background: rgba(138,128,112,0.15); color: #9CA3AF; }
        .pill-aktif { background: rgba(76,175,80,0.15); color: #22C55E; }
        .pill-nonaktif { background: rgba(239,68,68,0.15); color: #EF4444; }

        .mbr-date { font-size: 13px; color: var(--text); }
        .mbr-date.empty { color: var(--text-muted); }
        .mbr-sisa { font-size: 11px; margin-top: 3px; }
        .sisa-ok { color: #22C55E; }
        .sisa-warn { color: #F59E0B; }
        .sisa-expired { color: #EF4444; }

        .mbr-actions { display: flex; gap: 6px; align-items: center; }
        .mbr-icon-btn {
            width: 28px; height: 28px; border-radius: 6px; border: 1px solid var(--border);
            background: transparent; color: var(--muted); display: inline-flex;
            align-items: center; justify-content: center; font-size: 14px; cursor: pointer;
            transition: all 0.15s ease; padding: 0; text-decoration: none;
        }
        .mbr-icon-btn:hover { border-color: var(--accent); color: var(--accent); background: rgba(250,204,21,0.06); }
        .mbr-icon-btn.is-danger:hover { border-color: var(--danger); color: var(--danger); background: rgba(239,68,68,0.06); }

        .mbr-package-filters { display: flex; align-items: center; gap: 10px; margin-left: auto; flex-wrap: wrap; }

        /* Pagination footer &mdash; custom (menyatu di dalam card tabel) */
        .mbr-pagination {
            display: flex; justify-content: space-between; align-items: center;
            height: 48px; padding: 0 20px; border-top: 1px solid var(--border);
            background: var(--panel); border-radius: 0 0 10px 10px;
        }
        .mbr-result-count { font-size: 12px; color: var(--muted); }
        .mbr-pager { display: flex; align-items: center; gap: 6px; }
        .mbr-pager a, .mbr-pager span {
            display: inline-flex; align-items: center; justify-content: center;
            min-width: 32px; height: 32px; padding: 0 8px; border-radius: 6px;
            font-size: 13px; font-weight: 600; color: var(--muted);
            background: var(--panel); border: 1px solid var(--border);
            text-decoration: none; transition: all 0.15s ease;
        }
        .mbr-pager a:hover { border-color: var(--accent); color: var(--accent); }
        .mbr-pager .is-active {
            background: var(--accent); color: var(--on-accent); border-color: var(--accent);
        }
        .mbr-pager .is-ellipsis { border: 0; background: transparent; color: var(--text-muted); min-width: 24px; }
        .mbr-pager .is-nav {
            padding: 0 12px; font-size: 11px; font-weight: 700;
            text-transform: uppercase; letter-spacing: 1px;
        }
        .mbr-pager .is-disabled {
            color: var(--text-muted); border-color: #201F1F; cursor: not-allowed; opacity: 0.6;
        }

        .mbr-empty { padding: 48px 20px; text-align: center; }
        .mbr-empty__icon { font-size: 40px; }
        .mbr-empty__title { font-size: 16px; font-weight: 600; color: var(--muted); margin-top: 12px; }
        .mbr-empty__sub { font-size: 13px; color: var(--text-muted); margin-top: 8px; }

        .mbr-summary { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-top: 20px; }
        .mbr-sum-card {
            position: relative; overflow: hidden;
            background: var(--panel); border: 1px solid var(--border);
            border-radius: 10px; padding: 18px 20px; box-shadow: var(--shadow-card);
        }
        .mbr-sum-card__label { font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--muted); margin-bottom: 6px; }
        .mbr-sum-card__value { font-size: 36px; font-weight: 800; color: var(--text); line-height: 1; }
        .mbr-sum-card__sub { font-size: 12px; margin-top: 6px; color: var(--muted); }
        .mbr-sum-card__icon { position: absolute; top: 16px; right: 18px; font-size: 24px; opacity: 0.15; }
        .mbr-sum-card--featured { background: var(--accent); border: 0; box-shadow: 0 4px 16px rgba(250,204,21,0.25); }
        .mbr-sum-card--featured .mbr-sum-card__label { color: rgba(26,21,0,0.6); }
        .mbr-sum-card--featured .mbr-sum-card__value { color: var(--on-accent); }
        .mbr-sum-card--featured .mbr-sum-card__sub { color: rgba(26,21,0,0.7); }
        .mbr-sum-card__sub.is-positive { color: #22C55E; }
        .mbr-sum-card__sub.is-warn { color: #F59E0B; }

        @media (max-width: 1080px) {
            .mbr-grid { grid-template-columns: 1.6fr 1.4fr 0.8fr; }
            .mbr-col-status, .mbr-col-berakhir, .mbr-col-paket { display: none; }
            .mbr-summary { grid-template-columns: 1fr; }
        }
    </style>

    {{-- FILTER ROW: status membership + package chips + Tambah Baru --}}
    <div class="mbr-filter">
        <a href="{{ route('admin.members.index', ['status' => 'all', 'plan' => $activePlan, 'search' => $search]) }}"
            class="mbr-tab {{ $status === 'all' ? 'active' : '' }}">Semua</a>
        <a href="{{ route('admin.members.index', ['status' => 'active', 'plan' => $activePlan, 'search' => $search]) }}"
            class="mbr-tab {{ $status === 'active' ? 'active' : '' }}">Aktif</a>
        <a href="{{ route('admin.members.index', ['status' => 'inactive', 'plan' => $activePlan, 'search' => $search]) }}"
            class="mbr-tab {{ $status === 'inactive' ? 'active' : '' }}">Nonaktif</a>

        <div class="mbr-package-filters">
            <a href="{{ route('admin.members.index', ['status' => $status, 'search' => $search]) }}"
                class="mbr-tab {{ $activePlan === '' ? 'active' : '' }}">Semua Paket</a>
            @foreach ($plans as $package)
                <a href="{{ route('admin.members.index', ['status' => $status, 'plan' => $package->name, 'search' => $search]) }}"
                    class="mbr-tab {{ $activePlan === $package->name ? 'active' : '' }}">{{ $package->name }}</a>
            @endforeach
            <a href="{{ route('admin.members.create') }}" class="btn btn-primary">+ Tambah Baru</a>
        </div>
    </div>

    {{-- MEMBER TABLE --}}
    <div class="mbr-table-card">
        <div class="mbr-grid mbr-thead">
            <div>Nama</div>
            <div>Kontak</div>
            <div class="mbr-col-paket">Paket Aktif</div>
            <div class="mbr-col-status">Status Membership</div>
            <div class="mbr-col-berakhir">Berakhir</div>
            <div>Aksi</div>
        </div>

        @forelse ($members as $member)
            @php
                // Pakai logic RANTAI KONTIGU yang SAMA dengan Flutter (Home &
                // Membership) via helper MemberMembership -- agar angka identik
                // di semua tempat. "Paket aktif" & "berakhir" = row di UJUNG
                // rantai (paket yang paling akhir berlaku dalam rangkaian yang
                // tersambung dari hari ini), bukan sekadar 1 row aktif hari ini.
                $activeMembership = \App\Models\MemberMembership::activeChainMembership($member->memberships);
                $planName = $activeMembership?->membershipPlan?->name ?? '';
                $planKey = strtolower($planName);
                $pillClass = str_contains($planKey, 'platinum') ? 'pill-platinum'
                    : (str_contains($planKey, 'gold') ? 'pill-gold'
                    : (str_contains($planKey, 'pro') ? 'pill-pro' : 'pill-basic'));

                // Harus memakai sumber yang sama dengan filter Aktif/Nonaktif:
                // membership active + paid yang mencakup hari ini.
                $isMembershipActive = $activeMembership !== null;
                // Tanggal berakhir & sisa hari dari UJUNG rantai (konsisten).
                $endDate = \App\Models\MemberMembership::activeChainEndDate($member->memberships);
                $daysLeft = \App\Models\MemberMembership::remainingDaysForMember($member->memberships);

                $name = $member->user?->name ?? 'Member';
                $initials = collect(explode(' ', trim($name)))
                    ->filter()->take(2)
                    ->map(fn ($w) => mb_strtoupper(mb_substr($w, 0, 1)))
                    ->implode('');
            @endphp
            <div class="mbr-grid mbr-row">
                {{-- NAMA --}}
                <div class="mbr-name-cell">
                    <div class="mbr-avatar">
                        <x-member-avatar :avatar-url="$member->user?->avatar_url" :initials="$initials !== '' ? $initials : 'M'" :name="$name" />
                    </div>
                    <div>
                        <div class="mbr-name">{{ $name }}</div>
                        <div class="mbr-id">ID: {{ $member->member_code ?? '-' }}</div>
                    </div>
                </div>

                {{-- KONTAK --}}
                <div>
                    <div class="mbr-email">{{ $member->user?->email ?? '-' }}</div>
                    <div class="mbr-phone">{{ $member->user?->phone ?? '-' }}</div>
                </div>

                {{-- PAKET AKTIF --}}
                <div class="mbr-col-paket">
                    @if ($activeMembership)
                        <span class="pill {{ $pillClass }}">{{ $planName ?: 'Membership' }}</span>
                    @else
                        <span class="mbr-date empty">Tidak ada paket</span>
                    @endif
                </div>

                {{-- STATUS MEMBERSHIP --}}
                <div class="mbr-col-status">
                    <span class="pill {{ $isMembershipActive ? 'pill-aktif' : 'pill-nonaktif' }}">
                        {{ $isMembershipActive ? 'Aktif' : 'Nonaktif' }}
                    </span>
                </div>

                {{-- BERAKHIR --}}
                <div class="mbr-col-berakhir">
                    @if ($activeMembership && $endDate)
                                    <div class="mbr-date">{{ $endDate->locale('id')->translatedFormat('d F Y') }}</div>
                        @php $days = $daysLeft !== null ? (int) round($daysLeft) : null; @endphp
                        @if ($days !== null && $days < 0)
                            <div class="mbr-sisa sisa-expired">Expired</div>
                        @elseif ($days !== null && $days <= 30)
                            <div class="mbr-sisa sisa-warn">{{ $days }} hr sisa</div>
                        @elseif ($days !== null)
                            <div class="mbr-sisa sisa-ok">{{ $days }} hr sisa</div>
                        @endif
                    @else
                        <div class="mbr-date empty">&mdash;</div>
                    @endif
                </div>

                {{-- AKSI: kelola member --}}
                <div class="mbr-actions">
                    <a href="{{ route('admin.members.edit', $member) }}" class="mbr-icon-btn" title="Kelola member" aria-label="Kelola {{ $name }}">&#9998;</a>
                </div>
            </div>
        @empty
            <div class="mbr-empty">
                <div class="mbr-empty__icon">&#128101;</div>
                <div class="mbr-empty__title">Tidak ada member ditemukan</div>
                <div class="mbr-empty__sub">Coba ubah filter atau kata kunci pencarian.</div>
            </div>
        @endforelse

        {{-- PAGINATION FOOTER (custom, sesuai MD section 10) --}}
        <div class="mbr-pagination">
            <div class="mbr-result-count">
                @if ($members->total() > 0)
                    Showing {{ $members->firstItem() }}&ndash;{{ $members->lastItem() }} of {{ number_format($members->total(), 0, ',', '.') }} members
                @else
                    Showing 0 of 0 members
                @endif
            </div>

            @if ($members->lastPage() > 1)
                @php
                    $current = $members->currentPage();
                    $last = $members->lastPage();
                    // Window nomor halaman ringkas: 1 &hellip; (cur-1 cur cur+1) &hellip; last
                    $pages = collect(range(1, $last))->filter(function ($p) use ($current, $last) {
                        return $p === 1 || $p === $last || abs($p - $current) <= 1;
                    })->values();
                @endphp
                <div class="mbr-pager">
                    @if ($members->onFirstPage())
                        <span class="is-nav is-disabled">Prev</span>
                    @else
                        <a class="is-nav" href="{{ $members->previousPageUrl() }}">Prev</a>
                    @endif

                    @php $prev = 0; @endphp
                    @foreach ($pages as $p)
                        @if ($p - $prev > 1)
                            <span class="is-ellipsis">&middot;&middot;&middot;</span>
                        @endif
                        @if ($p === $current)
                            <span class="is-active">{{ $p }}</span>
                        @else
                            <a href="{{ $members->url($p) }}">{{ $p }}</a>
                        @endif
                        @php $prev = $p; @endphp
                    @endforeach

                    @if ($members->hasMorePages())
                        <a class="is-nav" href="{{ $members->nextPageUrl() }}">Next</a>
                    @else
                        <span class="is-nav is-disabled">Next</span>
                    @endif
                </div>
            @endif
        </div>
    </div>

    {{-- SUMMARY CARDS --}}
    <div class="mbr-summary">
        <div class="mbr-sum-card">
            <div class="mbr-sum-card__icon">&#128101;</div>
            <div class="mbr-sum-card__label">Total Members</div>
            <div class="mbr-sum-card__value">{{ number_format($summary['total_members'], 0, ',', '.') }}</div>
            <div class="mbr-sum-card__sub {{ $summary['growth_percent'] >= 0 ? 'is-positive' : '' }}">
                @if ($summary['growth_percent'] >= 0)&#8593; +@else&#8595; @endif{{ $summary['growth_percent'] }}% bulan ini
            </div>
        </div>
        <div class="mbr-sum-card mbr-sum-card--featured">
            <div class="mbr-sum-card__icon">&#9733;</div>
            <div class="mbr-sum-card__label">Active Membership</div>
            <div class="mbr-sum-card__value">{{ number_format($summary['active_membership'], 0, ',', '.') }}</div>
            <div class="mbr-sum-card__sub">Member dengan membership aktif</div>
        </div>
        <div class="mbr-sum-card">
            <div class="mbr-sum-card__icon">&#9888;</div>
            <div class="mbr-sum-card__label">Expiring Soon</div>
            <div class="mbr-sum-card__value">{{ number_format($summary['expiring_soon'], 0, ',', '.') }}</div>
            <div class="mbr-sum-card__sub is-warn">&#9888; Berakhir dalam 30 hari</div>
        </div>
    </div>
@endsection
