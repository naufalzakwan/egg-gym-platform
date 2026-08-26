@extends('admin.layouts.app')

@php
    $title = 'Laporan Operasional - EggGym Admin';
    $pageHeading = 'Laporan Operasional';
    $pageSubheading = 'Analisis pendapatan, pertumbuhan member, dan performa PT.';
@endphp

@section('content')
    <style>
        .rp-kpi { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; margin-bottom: 20px; }
        .rp-card { min-height: 142px; background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 18px 20px; box-shadow: var(--shadow-card); display: flex; flex-direction: column; }
        .rp-card__value { font-size: 32px; font-weight: 800; color: var(--text); line-height: 1; margin-top: 12px; }
        .rp-card__sub { min-height: 34px; font-size: 12px; line-height: 1.45; margin-top: 9px; color: var(--muted); }
        .rp-card__sub.up { color: #22C55E; }
        .rp-card__trend { display: block; margin-top: 2px; color: var(--muted); }
        .rp-card__trend.up { color: #22C55E; }
        .rp-card__label { font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--muted); }

        .rp-charts { display: flex; gap: 20px; margin-bottom: 20px; flex-wrap: wrap; }
        .rp-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 20px 24px; box-shadow: var(--shadow-card); }
        .rp-panel__title { font-size: 14px; font-weight: 700; color: var(--text); }
        .rp-panel__sub { font-size: 10px; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); margin-top: 2px; }
        .rp-revenue { flex: 1.5; min-width: 340px; }
        .rp-packages { flex: 1; min-width: 260px; display: flex; flex-direction: column; }

        .rp-bars { display: flex; align-items: flex-end; justify-content: space-between; gap: 8px; height: 220px; margin-top: 20px; padding: 0 4px 4px; overflow-x: auto; }
        .rp-bar-col { flex: 1 0 48px; display: flex; flex-direction: column; align-items: center; gap: 8px; height: 100%; justify-content: flex-end; }
        .rp-bar { width: 60%; min-height: 4px; border: 0; padding: 0; border-radius: 4px 4px 0 0; background: #2A2A2A; position: relative; cursor: pointer; transition: background 0.2s, box-shadow 0.2s, transform 0.2s; }
        .rp-bar:hover { background: #343434; transform: translateY(-2px); }
        .rp-bar:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
        .rp-bar.active { background: var(--accent); box-shadow: 0 0 8px rgba(250,204,21,0.3); }
        .rp-bar__val { position: absolute; top: -25px; left: 50%; transform: translateX(-50%); padding: 3px 7px; border-radius: 4px; background: var(--accent); color: var(--on-accent); font-size: 11px; font-weight: 700; white-space: nowrap; }
        .rp-bar-label { font-size: 11px; color: var(--muted); text-transform: uppercase; }

        .rp-donut-wrap { display: flex; flex-direction: column; align-items: center; margin: 16px 0; }
        .rp-legend { display: flex; flex-direction: column; gap: 8px; margin-top: 8px; }
        .rp-legend__item { display: flex; align-items: center; justify-content: space-between; }
        .rp-legend__left { display: flex; align-items: center; gap: 8px; }
        .rp-legend__dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
        .rp-legend__name { font-size: 12px; color: var(--text); }
        .rp-legend__pct { font-size: 12px; color: var(--muted); }

        .rp-rank { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 20px; box-shadow: var(--shadow-card); }
        .rp-rank__head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
        .rp-rgrid { display: grid; grid-template-columns: 0.5fr 2fr 1.6fr 0.9fr 1.1fr 1.1fr; gap: 12px; align-items: center; }
        .rp-rthead { padding: 10px 16px; background: var(--bg); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .rp-rrow { padding: 14px 16px; border-bottom: 1px solid var(--border); }
        .rp-rrow:last-child { border-bottom: 0; }
        .rp-rank-num { font-size: 16px; font-weight: 600; color: var(--muted); }
        .rp-rank-num.top { font-size: 18px; font-weight: 700; color: var(--accent); }
        .rp-trainer { display: flex; align-items: center; gap: 10px; }
        .rp-avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--panel-soft); display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; color: var(--accent); flex-shrink: 0; }
        .rp-tname { font-size: 13px; font-weight: 700; color: var(--text); }
        .rp-spec { font-size: 13px; color: var(--muted); }
        .rp-sessions { font-size: 13px; color: var(--text); }
        .rp-revenue-gain { font-size: 13px; font-weight: 700; color: var(--accent); }
        .rp-rating { color: var(--text); font-size: 13px; font-weight: 700; line-height: 1.35; }
        .rp-rating__star { color: var(--accent); }
        .rp-rating small { display: block; color: var(--muted); font-size: 10px; font-weight: 500; margin-top: 2px; }
        .rp-empty { display:grid;place-items:center;min-height:150px;color:var(--muted);font-size:12px;text-align:center; }

        @media (max-width: 1024px) {
            .rp-kpi { grid-template-columns: 1fr; }
            .rp-charts { flex-direction: column; }
            .rp-rgrid { grid-template-columns: 0.5fr 2fr 1fr 1.1fr; }
            .rp-col-spec, .rp-col-rating { display: none; }
        }
    </style>

    {{-- KPI CARDS --}}
    <div class="rp-kpi">
        <div class="rp-card">
            <div class="rp-card__label">Pendapatan Tahunan</div>
            <div class="rp-card__value" style="color: var(--accent);">{{ $kpi['revenue'] }}</div>
            <div class="rp-card__sub">
                Pendapatan bersih {{ $kpi['revenue_short_period_label'] }}
                <span class="rp-card__trend {{ $kpi['revenue_delta'] !== null && $kpi['revenue_delta'] >= 0 ? 'up' : '' }}">{{ $kpi['revenue_delta_label'] }}</span>
            </div>
        </div>
        <div class="rp-card">
            <div class="rp-card__label">Pertumbuhan Member</div>
            <div class="rp-card__value">{{ number_format($kpi['active_members'], 0, ',', '.') }} <span style="font-size:14px;color:var(--muted);">aktif</span></div>
            <div class="rp-card__sub">{{ number_format($kpi['new_members'], 0, ',', '.') }} Member baru bulan ini</div>
        </div>
        <div class="rp-card">
            <div class="rp-card__label">Transaksi Berhasil Tahun Ini</div>
            <div class="rp-card__value">{{ number_format($kpi['successful_transactions'], 0, ',', '.') }}</div>
            <div class="rp-card__sub">Transaksi membership sukses {{ $kpi['successful_period_label'] }}</div>
        </div>
    </div>

    {{-- CHARTS ROW --}}
    <div class="rp-charts">
        <div class="rp-panel rp-revenue">
            <div>
                <div class="rp-panel__title">Analisis Pendapatan</div>
                <div class="rp-panel__sub">Pendapatan Membership per Bulan</div>
            </div>
            <div class="rp-bars" id="report-revenue-chart">
                @foreach ($revenueTrend as $index => $m)
                    <div class="rp-bar-col">
                        <button type="button"
                            class="rp-bar {{ $m['is_active'] ? 'active' : '' }}"
                            style="height: {{ max(4, $m['height']) }}%;"
                            title="{{ $m['full_label'] }}: {{ $m['value_label'] }}"
                            aria-label="{{ $m['full_label'] }}: {{ $m['value_label'] }}"
                            aria-pressed="{{ $m['is_active'] ? 'true' : 'false' }}"
                            data-report-bar="{{ $index }}"
                            data-value-label="{{ $m['value_label'] }}">
                            @if ($m['is_active'])
                                <span class="rp-bar__val">{{ $m['value_label'] }}</span>
                            @endif
                        </button>
                        <span class="rp-bar-label">{{ $m['label'] }}</span>
                    </div>
                @endforeach
            </div>
        </div>

        <div class="rp-panel rp-packages">
            <div class="rp-panel__title">Distribusi Paket Membership</div>
            @php
                $circ = 2 * 3.14159 * 54;
                $offset = 0;
            @endphp
            @if($packageDistribution['total'] > 0)
            <div class="rp-donut-wrap">
                <svg width="160" height="160" viewBox="0 0 160 160">
                    <circle cx="80" cy="80" r="54" fill="none" stroke="#353534" stroke-width="28" />
                    @foreach ($packageDistribution['segments'] as $seg)
                        @php
                            $len = $circ * $seg['percent'] / 100;
                            $dash = $len . ' ' . ($circ - $len);
                            $rot = -90 + ($offset / 100 * 360);
                            $offset += $seg['percent'];
                        @endphp
                        <circle cx="80" cy="80" r="54" fill="none" stroke="{{ $seg['color'] }}" stroke-width="28"
                            stroke-dasharray="{{ $dash }}" transform="rotate({{ $rot }} 80 80)" />
                    @endforeach
                    <text x="80" y="76" text-anchor="middle" fill="#FFFFFF" font-size="24" font-weight="700">{{ $packageDistribution['total'] }}</text>
                    <text x="80" y="94" text-anchor="middle" fill="#9CA3AF" font-size="11">Member aktif</text>
                </svg>
            </div>
            <div class="rp-legend">
                @forelse ($packageDistribution['segments'] as $seg)
                    <div class="rp-legend__item">
                        <div class="rp-legend__left">
                            <span class="rp-legend__dot" style="background: {{ $seg['color'] }};"></span>
                            <span class="rp-legend__name">{{ $seg['name'] }}</span>
                        </div>
                        <span class="rp-legend__pct">{{ $seg['count'] }} Member &bull; {{ number_format($seg['percent'], 1, ',', '.') }}%</span>
                    </div>
                @empty
                    <div class="rp-legend__name" style="color: var(--muted);">Belum ada distribusi Membership aktif.</div>
                @endforelse
            </div>
            @else
                <div class="rp-empty">Belum ada distribusi Membership aktif.</div>
            @endif
        </div>
    </div>

    {{-- PT RANKING --}}
    <div class="rp-rank">
        <div class="rp-rank__head">
            <div>
                <div class="rp-panel__title">Peringkat Kinerja Personal Trainer</div>
                <div class="rp-panel__sub">Diurutkan berdasarkan total sesi terbayar, rating, lalu pendapatan PT</div>
            </div>
        </div>
        <div class="rp-rgrid rp-rthead">
            <div>Peringkat</div>
            <div>Personal Trainer</div>
            <div class="rp-col-spec">Spesialisasi</div>
            <div>Total Sesi</div>
            <div>Pendapatan PT</div>
            <div class="rp-col-rating">Rating</div>
        </div>
        @forelse ($ptRanking as $i => $pt)
            @php
                $rank = $i + 1;
                $init = strtoupper(mb_substr((string) $pt['name'], 0, 1));
            @endphp
            <div class="rp-rgrid rp-rrow">
                <div class="rp-rank-num {{ $rank === 1 ? 'top' : '' }}">#{{ str_pad((string) $rank, 2, '0', STR_PAD_LEFT) }}</div>
                <div class="rp-trainer">
                    <div class="rp-avatar">{{ $init }}</div>
                    <span class="rp-tname">{{ $pt['name'] }}</span>
                </div>
                <div class="rp-col-spec rp-spec">{{ $pt['specialty'] }}</div>
                <div class="rp-sessions">{{ $pt['total_sessions'] }}</div>
                <div class="rp-revenue-gain">{{ $pt['revenue'] }}</div>
                <div class="rp-col-rating rp-rating">
                    @if($pt['rating'] !== null)
                        {{ number_format($pt['rating'], 2, ',', '.') }} / 5 <span class="rp-rating__star">&#9733;</span>
                        <small>{{ number_format($pt['rating_count'], 0, ',', '.') }} ulasan</small>
                    @else
                        Belum ada rating
                    @endif
                </div>
            </div>
        @empty
            <div class="rp-rrow" style="color: var(--muted);">{{ $search !== '' ? 'Tidak ada data yang cocok.' : 'Belum ada data performa PT.' }}</div>
        @endforelse
    </div>
    <script>
        (() => {
            const chart = document.getElementById('report-revenue-chart');
            if (!chart) return;
            const bars = [...chart.querySelectorAll('[data-report-bar]')];
            const selectBar = (selected) => {
                bars.forEach((bar) => {
                    const active = bar === selected;
                    bar.classList.toggle('active', active);
                    bar.setAttribute('aria-pressed', active ? 'true' : 'false');
                    bar.querySelector('.rp-bar__val')?.remove();
                    if (active) {
                        const tooltip = document.createElement('span');
                        tooltip.className = 'rp-bar__val';
                        tooltip.textContent = bar.dataset.valueLabel;
                        bar.appendChild(tooltip);
                    }
                });
            };
            bars.forEach((bar) => bar.addEventListener('click', () => selectBar(bar)));
        })();
    </script>
@endsection
