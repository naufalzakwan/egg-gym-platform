@extends('admin.layouts.app')

@php
    $title = 'Physical Progress - EggGym Admin';
    $pageHeading = 'Physical Progress';
    $pageSubheading = 'Pantau progres berat badan & checkpoint member (khusus data numerik).';
@endphp

@section('content')
    <style>
        .pp-summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 20px; }
        .pp-stat { min-height: 144px; background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 20px 24px; box-shadow: var(--shadow-card); display: flex; flex-direction: column; justify-content: center; }
        .pp-stat__value { font-size: 32px; font-weight: 800; color: var(--text); line-height: 1; margin-top: 12px; }
        .pp-stat__value.accent { color: var(--accent); }
        .pp-stat__value.warn { color: var(--danger); }
        .pp-stat__label { font-size: 11px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); }
        .pp-stat__hint { font-size: 11px; color: var(--text-muted); margin-top: 8px; }

        .pp-filters { display: flex; align-items: center; gap: 10px; margin-bottom: 16px; flex-wrap: wrap; }
        .pp-filter { width: auto; min-width: 176px; height: 40px; padding: 0 34px 0 12px; border-radius: 6px; background: var(--panel); font-size: 13px; }
        .pp-filter:hover { border-color: var(--accent); }
        .pp-filter-reset { height: 40px; }

        .pp-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; box-shadow: var(--shadow-card); }
        .pp-grid { display: grid; grid-template-columns: 2.2fr 1.3fr 1.1fr 1.1fr 1.2fr 1fr; gap: 12px; align-items: center; }
        .pp-thead { background: var(--bg); padding: 13px 20px; font-size: 11px; font-weight: 700; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .pp-row { padding: 15px 20px; border-top: 1px solid var(--border); transition: background 0.15s ease; }
        .pp-row:hover { background: var(--panel-soft); }

        .pp-member { display: flex; align-items: center; gap: 12px; }
        .pp-avatar { width: 40px; height: 40px; border-radius: 50%; background: var(--panel-soft); display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 700; color: var(--accent); flex-shrink: 0; }
        .pp-name { font-size: 14px; font-weight: 700; color: var(--text); }
        .pp-goal { font-size: 11px; color: var(--muted); margin-top: 3px; }
        .pp-plan { font-size: 13px; color: var(--text); }
        .pp-plan__end { font-size: 11px; color: var(--muted); }
        .pp-weight { font-size: 15px; font-weight: 700; color: var(--text); }
        .pp-empty-cell { color: var(--text-muted); font-size: 12px; }
        .pp-change { display: inline-flex; align-items: center; padding: 4px 12px; border-radius: 999px; font-size: 13px; font-weight: 700; }
        .pp-change.good { background: rgba(34,197,94,0.15); color: #22C55E; }
        .pp-change.bad { background: rgba(239,68,68,0.15); color: #EF4444; }
        .pp-change.neutral { background: var(--panel-soft); color: var(--muted); }
        .pp-checkpoint { font-size: 14px; font-weight: 700; color: var(--text); }
        .pp-checkpoint__label { font-size: 10px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; }

        .pp-empty { padding: 40px; text-align: center; color: var(--muted); }

        @media (max-width: 1024px) {
            .pp-summary { grid-template-columns: 1fr; }
            .pp-filters { align-items: stretch; }
            .pp-filter { flex: 1 1 180px; }
            .pp-grid { grid-template-columns: 1.6fr 1.1fr 1.2fr 1fr; }
            .pp-col-plan, .pp-col-latest { display: none; }
        }
    </style>

    {{-- STAT CARDS --}}
    <div class="pp-summary">
        <div class="pp-stat">
            <div class="pp-stat__label">Member Dipantau</div>
            <div class="pp-stat__value accent">{{ $summary['total_tracked'] }}</div>
            <div class="pp-stat__hint">Punya minimal 1 checkpoint</div>
        </div>
        <div class="pp-stat">
            <div class="pp-stat__label">Rata-rata Perubahan BB</div>
            <div class="pp-stat__value">{{ $summary['avg_change'] > 0 ? '+' : '' }}{{ number_format($summary['avg_change'], 1) }} kg</div>
            <div class="pp-stat__hint">Baseline &rarr; terkini</div>
        </div>
        <div class="pp-stat">
            <div class="pp-stat__label">Perlu Perhatian</div>
            <div class="pp-stat__value {{ $summary['need_attention'] > 0 ? 'warn' : '' }}">{{ $summary['need_attention'] }}</div>
            <div class="pp-stat__hint">Member aktif tanpa checkpoint</div>
        </div>
    </div>

    <form class="pp-filters" method="GET" action="{{ route('admin.member-progress.index') }}">
        @if($search !== '')<input type="hidden" name="search" value="{{ $search }}">@endif
        <select class="pp-filter" name="checkpoint" onchange="this.form.submit()">
            <option value="">Checkpoint: Semua</option>
            <option value="tracked" {{ $checkpointFilter === 'tracked' ? 'selected' : '' }}>Sudah Ada Checkpoint</option>
            <option value="untracked" {{ $checkpointFilter === 'untracked' ? 'selected' : '' }}>Belum Ada Checkpoint</option>
        </select>
        <select class="pp-filter" name="membership" onchange="this.form.submit()">
            <option value="">Membership: Semua</option>
            <option value="active" {{ $membershipFilter === 'active' ? 'selected' : '' }}>Membership Aktif</option>
            <option value="inactive" {{ $membershipFilter === 'inactive' ? 'selected' : '' }}>Membership Tidak Aktif</option>
        </select>
        @if($checkpointFilter !== '' || $membershipFilter !== '')
            <a class="btn btn-secondary pp-filter-reset" href="{{ route('admin.member-progress.index', array_filter(['search' => $search])) }}">Reset Filter</a>
        @endif
    </form>

    {{-- TABLE --}}
    <div class="pp-panel">
        <div class="pp-grid pp-thead">
            <div>Member</div>
            <div class="pp-col-plan">Membership Aktif</div>
            <div>Berat Awal</div>
            <div class="pp-col-latest">Berat Terkini</div>
            <div>Perubahan BB</div>
            <div>Checkpoint</div>
        </div>

        @forelse ($rows as $row)
            @php $init = strtoupper(mb_substr($row->name, 0, 1)); @endphp
            <div class="pp-grid pp-row">
                {{-- Member --}}
                <div class="pp-member">
                    <div class="pp-avatar">
                        <x-member-avatar :avatar-url="$row->avatar_url ?? null" :initials="$init" :name="$row->name" />
                    </div>
                    <div>
                        <div class="pp-name">{{ $row->name }}</div>
                        <div class="pp-goal">{{ $row->member_code }} &middot; Goal: {{ $row->goal ?: '-' }}</div>
                    </div>
                </div>
                {{-- Membership Aktif --}}
                <div class="pp-col-plan">
                    @if ($row->plan_name)
                        <div class="pp-plan">{{ $row->plan_name }}</div>
                        <div class="pp-plan__end">s/d {{ $row->plan_end?->locale('id')->translatedFormat('d F Y') }}</div>
                    @else
                        <span class="pp-empty-cell">-</span>
                    @endif
                </div>
                {{-- Berat Awal --}}
                <div>
                    @if ($row->baseline_weight !== null)
                        <span class="pp-weight">{{ number_format($row->baseline_weight, 1) }} kg</span>
                    @else
                        <span class="pp-empty-cell">-</span>
                    @endif
                </div>
                {{-- Berat Terkini --}}
                <div class="pp-col-latest">
                    @if ($row->latest_weight !== null)
                        <span class="pp-weight">{{ number_format($row->latest_weight, 1) }} kg</span>
                    @else
                        <span class="pp-empty-cell">-</span>
                    @endif
                </div>
                {{-- Perubahan BB (warna ikut goal) --}}
                <div>
                    @if ($row->change !== null)
                        <span class="pp-change {{ $row->change_color }}">
                            {{ $row->change > 0 ? '+' : '' }}{{ number_format($row->change, 1) }} kg
                        </span>
                    @elseif ($row->has_checkpoint)
                        <span class="pp-empty-cell">-</span>
                    @else
                        <span class="pp-empty-cell">-</span>
                    @endif
                </div>
                {{-- Checkpoint --}}
                <div>
                    @if ($row->has_checkpoint)
                        <span class="pp-checkpoint">{{ $row->checkpoint_count }}/{{ $row->checkpoint_target }}</span>
                        <div class="pp-checkpoint__label">checkpoint</div>
                    @else
                        <span class="pp-empty-cell">-</span>
                    @endif
                </div>
            </div>
        @empty
            <div class="pp-empty">Belum ada member yang cocok dengan filter saat ini.</div>
        @endforelse

        @include('admin.partials.pagination', ['paginator' => $members, 'itemLabel' => 'member'])
    </div>
@endsection
