@extends('admin.layouts.app')

@php
    $title = 'Dashboard Admin EggGym';
    $pageHeading = 'Dashboard Overview';
    $pageSubheading = 'Ringkasan operasional real-time EggGym.';
@endphp

@section('content')
    <style>
        .dash-stat {
            position: relative;
            overflow: hidden;
        }
        .dash-stat__label {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            color: var(--muted);
            margin-bottom: 8px;
        }
        .dash-stat__number {
            font-size: 32px;
            font-weight: 800;
            color: var(--text);
            line-height: 1;
        }
        .dash-stat__sub {
            margin-top: 10px;
            font-size: 12px;
            color: var(--muted);
        }
        .dash-stat__sub.is-positive { color: var(--success); }
        .dash-stat__sub.is-negative { color: var(--danger); }
        .dash-stat--accent .dash-stat__label { color: rgba(26,21,0,0.7); }
        .dash-stat--accent .dash-stat__number,
        .dash-stat--accent .dash-stat__sub { color: var(--on-accent); }

        .dash-main-grid {
            display: grid;
            grid-template-columns: 1.6fr 1fr;
            grid-template-areas: "sales activity" "lower activity";
            gap: 20px;
            margin-top: 20px;
            align-items: stretch;
        }
        .dash-sales { grid-area: sales; }
        .dash-activity { grid-area: activity; display: flex; flex-direction: column; min-height: 100%; }
        .dash-lower { grid-area: lower; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }
        .dash-panel {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 24px;
            box-shadow: var(--shadow-card);
        }
        .dash-panel__title {
            font-size: 18px;
            font-weight: 700;
            margin: 0;
        }
        .dash-panel__subtitle {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 2px;
            text-transform: uppercase;
            color: var(--muted);
            margin: 4px 0 0;
        }
        .dash-panel__head {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 20px;
        }
        .chart-toggle { display: flex; border: 1px solid var(--border); border-radius: 6px; overflow: hidden; }
        .chart-toggle button {
            border: 0; background: transparent;
            padding: 6px 12px; font-size: 11px; font-weight: 600; letter-spacing: 1px;
            text-transform: uppercase; color: var(--muted); cursor: pointer;
        }
        .chart-toggle button.active { background: var(--accent); color: var(--on-accent); }

        .bar-chart {
            display: flex; align-items: flex-end; justify-content: space-between;
            gap: 12px; height: 220px; padding-top: 10px;
        }
        .bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 8px; height: 100%; justify-content: flex-end; }
        .bar-col__bar {
            width: 70%; min-height: 4px; border-radius: 4px 4px 0 0; background: var(--panel-soft);
            position: relative; border: 0; padding: 0; cursor: pointer;
            transition: background .18s ease, box-shadow .18s ease, transform .18s ease;
        }
        .bar-col__bar:hover { background: #343434; transform: translateY(-2px); }
        .bar-col__bar:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
        .bar-col__bar.is-active { background: var(--accent); box-shadow: 0 0 12px rgba(250,204,21,0.4); }
        .bar-col__tip {
            position: absolute; top: -22px; left: 50%; transform: translateX(-50%);
            background: var(--accent); color: var(--on-accent); font-size: 10px; font-weight: 700;
            padding: 3px 7px; border-radius: 4px; white-space: nowrap;
        }
        .bar-col__label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; }
        .chart-empty {
            height: 220px; display: flex; align-items: center; justify-content: center;
            color: var(--muted); font-size: 13px; text-align: center;
        }
        .chart-empty[hidden], .bar-chart[hidden] { display: none; }

        .activity-timeline { position: relative; flex: 1; }
        .activity-item { position: relative; display: flex; gap: 13px; padding: 0 0 20px; }
        .activity-item:not(:last-child)::before { content:""; position:absolute; left:18px; top:37px; bottom:0; width:1px; background:var(--border); }
        .activity-icon {
            width: 36px; height: 36px; border-radius: 50%; background: var(--panel-soft);
            display: flex; align-items: center; justify-content: center; flex-shrink: 0; font-size: 15px;
            border: 1px solid var(--border); position: relative; z-index: 1;
        }
        .activity-icon.is-yellow { color: var(--accent); background: rgba(250,204,21,.10); }
        .activity-icon.is-amber { color: var(--warning); background: rgba(245,158,11,.10); }
        .activity-icon.is-blue { color: var(--info); background: rgba(59,130,246,.10); }
        .activity-icon.is-cyan { color: #22D3EE; background: rgba(34,211,238,.10); }
        .activity-icon.is-red { color: var(--danger); background: rgba(239,68,68,.10); }
        .activity-icon.is-green { color: var(--success); background: rgba(34,197,94,.10); }
        .activity-content { min-width: 0; flex: 1; padding-top: 1px; }
        .activity-title { font-size: 14px; font-weight: 600; line-height: 1.3; }
        .activity-meta { font-size: 11px; color: var(--muted); margin-top: 5px; line-height: 1.45; }

        .pt-row { margin-bottom: 14px; }
        .pt-row__head { display: flex; justify-content: space-between; font-size: 13px; }
        .pt-row__name { color: var(--text); font-weight: 500; }
        .pt-row__count { color: var(--accent); font-weight: 700; }
        .pt-row__track { height: 6px; background: var(--panel-soft); border-radius: 3px; margin-top: 6px; overflow: hidden; }
        .pt-row__fill { height: 100%; background: var(--accent); border-radius: 3px; }

        .insight-row { display: flex; align-items: center; gap: 14px; padding: 10px 0; border-bottom: 1px solid var(--border); }
        .insight-icon { width: 36px; height: 36px; border-radius: 8px; background: var(--panel-soft); display: flex; align-items: center; justify-content: center; font-size: 16px; }
        .insight-label { font-size: 10px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); }
        .insight-value { font-size: 15px; font-weight: 700; color: var(--text); }
        .audit-log-btn {
            display: block; width: 100%; margin-top: 16px; padding: 11px 16px; background: transparent;
            border: 1px solid var(--border); border-radius: 6px; text-align: center; font-size: 11px;
            font-weight: 700; letter-spacing: 1px; text-transform: uppercase; color: var(--muted);
        }
        .audit-log-btn:hover { border-color: var(--accent); color: var(--accent); }

        .footer-bar {
            display: flex; align-items: center; gap: 40px; flex-wrap: wrap;
            background: var(--panel); border: 1px solid var(--border); border-radius: 14px;
            padding: 18px 24px; margin-top: 20px;
        }
        .footer-stat__label { font-size: 10px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); margin-bottom: 4px; }
        .footer-stat__value { font-size: 20px; font-weight: 800; }
        .footer-stat__value small { font-size: 12px; font-weight: 600; color: var(--success); margin-left: 6px; }
        .footer-stat--ts { margin-left: auto; text-align: right; }

        @media (max-width: 1080px) {
            .dash-main-grid { grid-template-columns: 1fr; grid-template-areas: "sales" "activity" "lower"; }
        }
        @media (max-width: 720px) {
            .dash-lower { grid-template-columns: 1fr; }
        }
    </style>

    {{-- 1. STAT CARDS --}}
    <div class="grid grid-4">
        <div class="stat-card dash-stat">
            <div class="dash-stat__label">Total Member Aktif</div>
            <div class="dash-stat__number">{{ number_format($stats['total_member']['value'], 0, ',', '.') }}</div>
            <div class="dash-stat__sub {{ $stats['total_member']['delta'] >= 0 ? 'is-positive' : 'is-negative' }}">
                {{ $stats['total_member']['sub'] }}
            </div>
        </div>
        <div class="stat-card dash-stat">
            <div class="dash-stat__label">Total PT Aktif</div>
            <div class="dash-stat__number">{{ number_format($stats['total_pt']['value'], 0, ',', '.') }}</div>
            <div class="dash-stat__sub">Trainer aktif tersedia</div>
        </div>
        <div class="stat-card dash-stat">
            <div class="dash-stat__label">Booking Hari Ini</div>
            <div class="dash-stat__number">{{ number_format($stats['booking_today']['value'], 0, ',', '.') }}</div>
            <div class="dash-stat__sub">
                {{ $stats['booking_today']['value'] > 0 ? 'Booking terjadwal hari ini' : 'Belum ada booking hari ini' }}
            </div>
        </div>
        <div class="stat-card dash-stat dash-stat--accent stat-card--accent">
            <div class="dash-stat__label">Pendapatan Bulan Ini</div>
            <div class="dash-stat__number">{{ $stats['revenue']['value_label'] }}</div>
            <div class="dash-stat__sub">{{ $stats['revenue']['sub'] }}</div>
        </div>
    </div>

    {{-- 2. SALES + LOWER LEFT, RECENT ACTIVITY SPANS RIGHT --}}
    <div class="dash-main-grid" data-dashboard-layout>
        <div class="dash-panel dash-sales">
            <div class="dash-panel__head">
                <div>
                    <h3 class="dash-panel__title">Membership Sales Trend</h3>
                    <p class="dash-panel__subtitle" id="sales-trend-subtitle">Pendapatan membership (6 bulan)</p>
                </div>
                <div class="chart-toggle" role="tablist" aria-label="Periode grafik">
                    <button type="button" role="tab" data-period="weekly" aria-selected="false">Weekly</button>
                    <button type="button" role="tab" data-period="monthly" class="active" aria-selected="true">Monthly</button>
                </div>
            </div>
            <div class="bar-chart" id="membership-sales-chart" role="img" aria-label="Grafik pendapatan membership"></div>
            <div class="chart-empty" id="membership-sales-empty" hidden>Belum ada transaksi membership berhasil pada periode ini.</div>
        </div>

        <div class="dash-panel dash-activity">
            <div class="dash-panel__head">
                <div>
                    <h3 class="dash-panel__title">Recent Activity</h3>
                    <p class="dash-panel__subtitle">Real-time Gym Logs</p>
                </div>
            </div>
            <div class="activity-timeline">
                @forelse ($recentActivity as $activity)
                    <div class="activity-item" data-activity-type="{{ $activity['type'] }}" data-audit-category="{{ $activity['category'] }}">
                        <div class="activity-icon is-{{ $activity['tone'] }}">{!! $activity['icon'] !!}</div>
                        <div class="activity-content">
                            <div class="activity-title">{{ $activity['title'] }}</div>
                            <div class="activity-meta">{{ $activity['meta'] }}</div>
                        </div>
                    </div>
                @empty
                    <p style="color: var(--muted);">Belum ada aktivitas Audit Trail.</p>
                @endforelse
            </div>
            <a href="{{ route('admin.audit-trail.index') }}" class="audit-log-btn">View Full Audit Log</a>
        </div>

        <div class="dash-lower">
        <div class="dash-panel">
            <div class="dash-panel__head">
                <h3 class="dash-panel__title">Booking PT Trend</h3>
            </div>
            @forelse ($ptTrend as $pt)
                <div class="pt-row">
                    <div class="pt-row__head">
                        <span class="pt-row__name">{{ $pt['name'] }}</span>
                        <span class="pt-row__count">{{ $pt['count'] }} Sesi</span>
                    </div>
                    <div class="pt-row__track"><div class="pt-row__fill" style="width: {{ $pt['percent'] }}%;"></div></div>
                </div>
            @empty
                <p style="color: var(--muted);">Belum ada data booking trainer.</p>
            @endforelse
        </div>

        <div class="dash-panel">
            <div class="dash-panel__head">
                <h3 class="dash-panel__title">Quick Insights</h3>
            </div>
            <div class="insight-row">
                <div class="insight-icon">&#11088;</div>
                <div>
                    <div class="insight-label">Paket Paling Populer</div>
                    <div class="insight-value">{{ $quickInsights['popular_plan'] }}</div>
                </div>
            </div>
            <div class="insight-row">
                <div class="insight-icon">&#128100;</div>
                <div>
                    <div class="insight-label">PT Sesi Terbanyak</div>
                    <div class="insight-value">{{ $quickInsights['top_trainer'] }}</div>
                </div>
            </div>
            <div class="insight-row" style="border-bottom: 0;">
                <div class="insight-icon">&#127947;</div>
                <div>
                    <div class="insight-label">Alat Gym Terbaru</div>
                    <div class="insight-value">{{ $quickInsights['latest_equipment'] }}</div>
                </div>
            </div>
        </div>
        </div>
    </div>

    {{-- 4. FOOTER STATS BAR --}}
    <div class="footer-bar">
        <div class="footer-stat">
            <div class="footer-stat__label">Member Growth</div>
            <div class="footer-stat__value">{{ $footer['member_growth'] }}%</div>
        </div>
        <div class="footer-stat">
            <div class="footer-stat__label">Member Retention</div>
            <div class="footer-stat__value">{{ $footer['retention_rate'] }}%</div>
        </div>
        <div class="footer-stat">
            <div class="footer-stat__label">Active PT</div>
            <div class="footer-stat__value">{{ $footer['active_pt'] }} / {{ $footer['total_pt'] }}</div>
        </div>
        <div class="footer-stat footer-stat--ts">
            <div class="footer-stat__label">Last Update</div>
            <div class="footer-stat__value" style="font-size: 13px; font-weight: 500;">{{ $footer['last_update'] }}</div>
        </div>
    </div>

    <script>
        (() => {
            const trends = @json($salesTrends);
            const chart = document.getElementById('membership-sales-chart');
            const empty = document.getElementById('membership-sales-empty');
            const subtitle = document.getElementById('sales-trend-subtitle');
            const buttons = document.querySelectorAll('.chart-toggle button[data-period]');

            const render = (period) => {
                const points = trends[period] || [];
                const hasRevenue = points.some((point) => Number(point.value) > 0);
                chart.replaceChildren();
                chart.hidden = !hasRevenue;
                empty.hidden = hasRevenue;
                subtitle.textContent = period === 'weekly'
                    ? 'Pendapatan membership (6 minggu)'
                    : 'Pendapatan membership (6 bulan)';

                if (hasRevenue) {
                    let selectedIndex = Math.max(0, points.findIndex((point) => point.is_active));
                    const selectBar = (index) => {
                        selectedIndex = index;
                        chart.querySelectorAll('.bar-col__bar').forEach((bar, barIndex) => {
                            const active = barIndex === selectedIndex;
                            bar.classList.toggle('is-active', active);
                            bar.setAttribute('aria-pressed', active ? 'true' : 'false');
                            bar.querySelector('.bar-col__tip')?.remove();
                            if (active) {
                                const tip = document.createElement('span');
                                tip.className = 'bar-col__tip';
                                tip.textContent = points[barIndex].value_label;
                                bar.appendChild(tip);
                            }
                        });
                    };

                    points.forEach((point, index) => {
                        const column = document.createElement('div');
                        column.className = 'bar-col';

                        const bar = document.createElement('button');
                        bar.type = 'button';
                        bar.className = 'bar-col__bar';
                        bar.style.height = `${Math.max(4, Number(point.height_percent) || 0)}%`;
                        bar.title = `${point.label}: ${point.value_label}`;
                        bar.setAttribute('aria-label', `${point.label}: ${point.value_label}`);
                        bar.setAttribute('aria-pressed', 'false');
                        bar.addEventListener('click', () => selectBar(index));

                        const label = document.createElement('span');
                        label.className = 'bar-col__label';
                        label.textContent = point.label;
                        column.append(bar, label);
                        chart.appendChild(column);
                    });
                    selectBar(selectedIndex);
                }

                buttons.forEach((button) => {
                    const active = button.dataset.period === period;
                    button.classList.toggle('active', active);
                    button.setAttribute('aria-selected', active ? 'true' : 'false');
                });
            };

            buttons.forEach((button) => {
                button.addEventListener('click', () => render(button.dataset.period));
            });
            render('monthly');
        })();
    </script>
@endsection
