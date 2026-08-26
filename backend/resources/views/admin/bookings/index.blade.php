@extends('admin.layouts.app')

@php
    $title = 'Booking & Sesi PT - EggGym Admin';
    $pageHeading = 'Booking & Sesi Monitoring';
    $pageSubheading = 'Pantau booking, sesi berlangsung, dan reassign Personal Trainer.';

    // Status DB nyata &#8594; label + warna badge.
    $statusMeta = function ($status) {
        return match ($status) {
            'pending' => ['label' => 'Menunggu Konfirmasi', 'cls' => 'bk-badge-menunggu'],
            'rescheduled' => ['label' => 'Dijadwalkan Ulang', 'cls' => 'bk-badge-menunggu'],
            'waiting_payment' => ['label' => 'Menunggu Pembayaran', 'cls' => 'bk-badge-dikonfirmasi'],
            'payment_uploaded' => ['label' => 'Bukti Diunggah', 'cls' => 'bk-badge-dikonfirmasi'],
            'payment_rejected' => ['label' => 'Pembayaran Ditolak', 'cls' => 'bk-badge-menunggu'],
            'payment_verified' => ['label' => 'Pembayaran Terverifikasi', 'cls' => 'bk-badge-dikonfirmasi'],
            'confirmed' => ['label' => 'Dikonfirmasi', 'cls' => 'bk-badge-dikonfirmasi'],
            'completed' => ['label' => 'Selesai', 'cls' => 'bk-badge-selesai'],
            'cancelled' => ['label' => 'Ditolak', 'cls' => 'bk-badge-ditolak'],
            'expired' => ['label' => 'Kedaluwarsa', 'cls' => 'bk-badge-ditolak'],
            'rejected' => ['label' => 'Ditolak', 'cls' => 'bk-badge-ditolak'],
            default => ['label' => ucfirst($status), 'cls' => 'bk-badge-menunggu'],
        };
    };
@endphp

@section('content')
    <style>
        .bk-wrap { display: grid; grid-template-columns: 63fr 37fr; gap: 20px; align-items: start; }
        .bk-tabs { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
        .bk-tab {
            padding: 10px 18px; border-radius: 6px; font-size: 13px; font-weight: 500; letter-spacing: 1px;
            text-transform: uppercase; color: var(--muted); background: transparent; border: 0;
            text-decoration: none; transition: all 0.15s ease; display: inline-flex; align-items: center; gap: 8px;
        }
        .bk-tab:hover { color: var(--accent); background: rgba(250,204,21,0.08); }
        .bk-tab.active { background: var(--accent); color: var(--on-accent); font-weight: 700; box-shadow: 0 2px 8px rgba(250,204,21,0.25); }
        .bk-tab__count { font-size: 11px; opacity: 0.75; }

        .bk-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; box-shadow: var(--shadow-card); }
        .bk-grid { display: grid; grid-template-columns: 2.5fr 1.8fr 1.8fr 1.4fr; gap: 12px; align-items: center; }
        .bk-thead { background: var(--bg); padding: 12px 20px; font-size: 11px; font-weight: 700; color: var(--muted); letter-spacing: 1.5px; text-transform: uppercase; }
        .bk-row { padding: 16px 20px; border-top: 1px solid var(--border); cursor: pointer; transition: background 0.15s ease; }
        .bk-row:hover { background: var(--panel-soft); }

        .bk-member { display: flex; align-items: center; gap: 12px; }
        .bk-avatar { width: 44px; height: 44px; border-radius: 50%; flex-shrink: 0; background: linear-gradient(135deg,#2A2A2A,#131313); display: flex; align-items: center; justify-content: center; font-weight: 700; color: var(--accent); }
        .bk-member__name { font-size: 16px; font-weight: 700; color: var(--text); }
        .bk-member__sub { font-size: 10px; color:var(--muted); margin-top:3px; }

        .bk-pt { display: flex; align-items: center; gap: 8px; position: relative; }
        .bk-pt__swap { background: transparent; border: 0; color: var(--accent); font-size: 15px; cursor: pointer; padding: 2px 4px; line-height: 1; }
        .bk-pt__swap:hover { transform: scale(1.15); }
        .bk-pt__name { font-size: 14px; font-weight: 600; color: var(--text); }
        .bk-swap-menu {
            display: none; position: absolute; left: 0; top: 110%; z-index: 30; min-width: 220px;
            background: var(--panel); border: 1px solid var(--border); border-radius: 8px; box-shadow: var(--shadow-hover); padding: 10px;
        }
        .bk-swap-menu.is-open { display: block; }
        .bk-swap-menu select { width: 100%; height: 34px; margin-bottom: 8px; }

        .bk-jadwal__date { font-size: 14px; font-weight: 600; color: var(--text); font-family: "JetBrains Mono", monospace; }
        .bk-jadwal__time { font-size: 13px; color: var(--muted); font-family: "JetBrains Mono", monospace; }

        .bk-badge { display: inline-flex; padding: 5px 10px; border-radius: 4px; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
        .bk-badge-menunggu { background: #FACC15; color: #131313; }
        .bk-badge-dikonfirmasi { background: #3B82F6; color: #fff; }
        .bk-badge-selesai { background: #22C55E; color: #fff; }
        .bk-badge-ditolak { background: #EF4444; color: #fff; }

        .bk-empty { padding: 40px 20px; text-align: center; color: var(--muted); }
        .bk-pagination { padding: 14px 20px; border-top: 1px solid var(--border); }

        /* Right column */
        .bk-live-head { display: flex; align-items: center; gap: 8px; margin-bottom: 16px; }
        .bk-live-title { font-size: 16px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--text); }
        .bk-live-dot { width: 8px; height: 8px; border-radius: 50%; background: #EF4444; box-shadow: 0 0 6px rgba(239,68,68,0.6); animation: bk-pulse 1.2s ease-in-out infinite; }
        @keyframes bk-pulse { 0%,100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.4); opacity: 0.6; } }

        .bk-live-card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 16px; margin-bottom: 12px; box-shadow: var(--shadow-card); }
        .bk-live-card__head { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
        .bk-live-card__name { font-size: 15px; font-weight: 700; color: var(--text); }
        .bk-live-card__coach { font-size: 11px; font-weight: 600; color: var(--muted); letter-spacing: 0.5px; text-transform: uppercase; margin-top: 2px; }
        .bk-live-prog { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
        .bk-live-prog__label { font-size: 10px; font-weight: 700; color: var(--muted); letter-spacing: 1.5px; text-transform: uppercase; }
        .bk-live-prog__pct { font-size: 20px; font-weight: 800; color: var(--accent); }
        .bk-live-track { height: 6px; background: #2A2A2A; border-radius: 3px; margin-bottom: 10px; overflow: hidden; }
        .bk-live-fill { height: 100%; background: var(--accent); border-radius: 3px; transition: width 0.5s ease; }
        .bk-live-meta { display: flex; justify-content: space-between; font-size: 11px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .bk-live-session { color: var(--text); font-size: 13px; font-weight: 800; margin-bottom: 4px; }
        .bk-live-sets { color: var(--muted); font-size: 10px; margin-top: 8px; }
        .bk-live-state { padding:18px; border:1px dashed var(--border); border-radius:12px; color:var(--muted); font-size:12px; line-height:1.55; text-align:center; }
        .bk-live-state button { margin-top:10px; }
        .bk-loading { position:fixed; inset:0; z-index:1200; display:flex; align-items:center; justify-content:center; background:rgba(8,8,8,.7); backdrop-filter:blur(3px); color:var(--accent); font-size:12px; font-weight:900; letter-spacing:1px; text-transform:uppercase; }
        .bk-loading[hidden] { display:none; }
        .bk-overdue { margin-bottom: 18px; border: 1px solid rgba(245,158,11,.5); border-radius: 12px; background: rgba(245,158,11,.08); overflow: hidden; }
        .bk-overdue__head { padding: 14px 18px; color: #FBBF24; font-size: 13px; font-weight: 900; letter-spacing: 1px; text-transform: uppercase; border-bottom: 1px solid rgba(245,158,11,.25); }
        .bk-overdue__item { display: grid; grid-template-columns: 1.2fr 1.2fr 1.5fr .9fr auto; gap: 12px; align-items: center; padding: 13px 18px; border-top: 1px solid rgba(245,158,11,.16); font-size: 12px; }
        .bk-overdue__item:first-of-type { border-top: 0; }
        .bk-overdue__muted { color: var(--muted); font-size: 10px; margin-top: 3px; }

        /* Drawer */
        .bk-drawer-backdrop { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 500; }
        .bk-drawer-backdrop.is-open { display: block; }
        .bk-drawer {
            position: fixed; top: 0; right: 0; height: 100vh; width: 460px; max-width: 92vw; z-index: 501;
            background: var(--panel); border-left: 1px solid var(--border); box-shadow: -8px 0 32px rgba(0,0,0,0.6);
            transform: translateX(100%); transition: transform 0.28s ease-out; padding: 24px; overflow-y: auto;
        }
        .bk-drawer.is-open { transform: translateX(0); }
        .bk-drawer__head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px; }
        .bk-drawer__close { background: transparent; border: 1px solid var(--border); color: var(--muted); border-radius: 6px; width: 30px; height: 30px; cursor: pointer; }
        .bk-drawer__row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid var(--border); font-size: 13px; }
        .bk-drawer__row .lbl { color: var(--muted); }
        .bk-drawer__row .val { color: var(--text); font-weight: 600; text-align: right; }
        .bk-drawer__actions { display: flex; gap: 10px; margin-top: 20px; flex-wrap: wrap; }

        @media (max-width: 1080px) {
            .bk-wrap { grid-template-columns: 1fr; }
            .bk-grid { grid-template-columns: 2fr 1.4fr 0.8fr; }
            .bk-col-jadwal { display: none; }
        }
    </style>

    @if (session('error'))
        <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">{{ session('error') }}</div>
    @endif

    @if($overdueVerifications->isNotEmpty())
        <section class="bk-overdue" aria-label="Verifikasi pembayaran terlambat">
            <div class="bk-overdue__head">Verifikasi Pembayaran Terlambat · {{ $overdueVerifications->count() }}</div>
            @foreach($overdueVerifications as $overdue)
                <div class="bk-overdue__item">
                    <div><strong>{{ $overdue['member_name'] }}</strong><div class="bk-overdue__muted">Booking #{{ $overdue['id'] }}</div></div>
                    <div><strong>{{ $overdue['trainer_name'] }}</strong><div class="bk-overdue__muted">Personal Trainer</div></div>
                    <div>{{ $overdue['trainer_phone'] }}<div class="bk-overdue__muted">{{ $overdue['trainer_email'] }}</div></div>
                    <div><strong>{{ $overdue['overdue_label'] }}</strong><div class="bk-overdue__muted">Upload {{ $overdue['uploaded_at']?->locale('id')->translatedFormat('d M Y H:i') ?? '-' }}</div></div>
                    <div style="display:flex;gap:8px;">
                        <a class="btn btn-secondary" href="{{ route('admin.bookings.index', ['status' => 'dikonfirmasi', 'search' => '#'.$overdue['id']]) }}">Lihat Booking</a>
                        @if($overdue['proof_url'])<a class="btn btn-secondary" href="{{ $overdue['proof_url'] }}" target="_blank" rel="noopener">Bukti</a>@endif
                    </div>
                </div>
            @endforeach
        </section>
    @endif

    <div class="bk-wrap">
        {{-- LEFT: tabs + table --}}
        <div>
            <div class="bk-tabs" role="tablist">
                @foreach (['menunggu' => 'Menunggu', 'dikonfirmasi' => 'Dikonfirmasi', 'selesai' => 'Selesai', 'ditolak' => 'Ditolak'] as $key => $label)
                    <a href="{{ route('admin.bookings.index', ['status' => $key, 'search' => $search]) }}"
                        class="bk-tab {{ $tab === $key ? 'active' : '' }}" data-booking-navigation role="tab" aria-selected="{{ $tab === $key ? 'true' : 'false' }}">
                        {{ $label }} <span class="bk-tab__count">{{ $counts[$key] ?? 0 }}</span>
                    </a>
                @endforeach
            </div>

            <div class="bk-panel">
                <div class="bk-grid bk-thead">
                    <div>Member</div>
                    <div>Personal Trainer</div>
                    <div class="bk-col-jadwal">Jadwal</div>
                    <div>Status</div>
                </div>

                @forelse ($bookings as $booking)
                    @php
                        $member = $booking->memberProfile;
                        $memberName = $member->user->name;
                        $sm = $statusMeta($booking->status);
                        $coachName = $booking->trainerProfile->user->name;
                        $init = strtoupper(mb_substr($memberName, 0, 1));
                        $occurrence = $booking->sessionReservations->first();
                        $scheduleDate = $occurrence?->session_date ?? $booking->session_date;
                        $scheduleStart = $occurrence?->start_time ?? $booking->start_time;
                        $scheduleEnd = $occurrence?->end_time ?? $booking->end_time;
                        $dateStr = $scheduleDate?->locale('id')->translatedFormat('d F Y') ?? '-';
                        $timeStr = substr((string) $scheduleStart, 0, 5) . ' - ' . substr((string) $scheduleEnd, 0, 5);
                        $scheduleSummary = $booking->sessionReservations->count() > 1
                            ? $booking->sessionReservations->count() . ' sesi terjadwal'
                            : null;
                    @endphp
                    <div class="bk-grid bk-row"
                        onclick="bkOpenDrawer(this)"
                        data-id="{{ $booking->id }}"
                        data-member="{{ $memberName }}"
                        data-coach="{{ $coachName }}"
                        data-date="{{ $dateStr }}"
                        data-time="{{ $timeStr }}"
                        data-location="{{ $booking->location ?? '-' }}"
                        data-status="{{ $sm['label'] }}"
                        data-note="{{ $booking->member_note ?? '-' }}"
                        data-can-confirm="{{ in_array($booking->status, ['pending','rescheduled']) ? '1' : '0' }}"
                        data-confirm-url="{{ route('admin.bookings.confirm', $booking) }}">
                        {{-- Member --}}
                        <div class="bk-member">
                            <div class="bk-avatar"><x-member-avatar :avatar-url="$member?->user?->avatar_url" :initials="$init" :name="$memberName" /></div>
                            <div>
                                <div class="bk-member__name">{{ $memberName }}</div>
                                <div class="bk-member__sub">Booking #{{ $booking->id }}</div>
                            </div>
                        </div>
                        {{-- Personal Trainer + swap --}}
                        <div class="bk-pt" onclick="event.stopPropagation()">
                            <button type="button" class="bk-pt__swap" title="Ganti Personal Trainer"
                                onclick="bkToggleSwap(this)" aria-label="Ganti PT untuk {{ $memberName }}">&#8645;</button>
                            <span class="bk-pt__name">{{ $coachName }}</span>
                            <div class="bk-swap-menu">
                                <form method="POST" action="{{ route('admin.bookings.reassign-trainer', $booking) }}">
                                    @csrf @method('PATCH')
                                    <select name="trainer_profile_id" required>
                                        <option value="">Pilih PT...</option>
                                        @foreach ($availableTrainers as $t)
                                            <option value="{{ $t['id'] }}" {{ $t['id'] == $booking->trainer_profile_id ? 'selected' : '' }}>{{ $t['name'] }}</option>
                                        @endforeach
                                    </select>
                                    <button type="submit" class="btn btn-primary" style="width:100%;">Ganti PT</button>
                                </form>
                            </div>
                        </div>
                        {{-- Jadwal --}}
                        <div class="bk-col-jadwal">
                            <div class="bk-jadwal__date">{{ $dateStr }}</div>
                            <div class="bk-jadwal__time">{{ $timeStr }}</div>
                            @if($scheduleSummary)<div class="bk-member__sub">{{ $scheduleSummary }}</div>@endif
                        </div>
                        {{-- Status --}}
                        <div><span class="bk-badge {{ $sm['cls'] }}">{{ $sm['label'] }}</span></div>
                    </div>
                @empty
                    <div class="bk-empty">
                        @if ($search !== '')
                            Tidak ada data yang cocok.
                        @else
                            @switch($tab)
                                @case('menunggu') Tidak ada booking menunggu konfirmasi. @break
                                @case('dikonfirmasi') Tidak ada sesi yang dikonfirmasi. @break
                                @case('selesai') Belum ada sesi yang selesai. @break
                                @default Tidak ada booking yang ditolak.
                            @endswitch
                        @endif
                    </div>
                @endforelse

                @include('admin.partials.pagination', ['paginator' => $bookings, 'itemLabel' => 'booking'])
            </div>
        </div>

        {{-- RIGHT: live progress + incentive --}}
        <div>
            <div class="bk-live-head">
                <span class="bk-live-dot"></span>
                <span class="bk-live-title">Live Progress</span>
            </div>

            <div id="bkLiveProgress" aria-live="polite">
            @forelse ($liveSessions as $ls)
                <div class="bk-live-card">
                    <div class="bk-live-card__head">
                        <div class="bk-avatar" style="width:44px;height:44px;"><x-member-avatar
                            :avatar-url="$ls['member_avatar_url'] ?? null"
                            :initials="strtoupper(mb_substr($ls['member_name'], 0, 1))"
                            :name="$ls['member_name']" /></div>
                        <div>
                            <div class="bk-live-card__name">{{ $ls['member_name'] }}</div>
                            <div class="bk-live-card__coach">With Coach {{ $ls['coach_name'] }}</div>
                        </div>
                    </div>
                    <div class="bk-live-prog">
                        <span class="bk-live-prog__label">Training Progress</span>
                        <span class="bk-live-prog__pct">{{ $ls['progress'] }}%</span>
                    </div>
                    <div class="bk-live-track"><div class="bk-live-fill" style="width: {{ $ls['progress'] }}%;"></div></div>
                    <div class="bk-live-session">{{ $ls['program_name'] ?? '-' }} · {{ $ls['session_name'] ?? '-' }}</div>
                    <div class="bk-live-meta">
                        <span>{{ $ls['status'] === 'active' ? 'Sedang Berjalan' : strtoupper($ls['status']) }}</span>
                        @if($ls['session_number'])<span>Session: #{{ str_pad((string) $ls['session_number'], 2, '0', STR_PAD_LEFT) }}</span>@endif
                    </div>
                    <div class="bk-live-sets">{{ $ls['completed_sets'] }}/{{ $ls['total_sets'] }} set selesai · {{ $ls['completed_exercises'] }}/{{ $ls['total_exercises'] }} latihan</div>
                </div>
            @empty
                <div class="bk-live-state">
                    Tidak ada sesi yang sedang berlangsung saat ini.
                </div>
            @endforelse
            </div>
        </div>
    </div>

    {{-- DETAIL DRAWER --}}
    <div class="bk-drawer-backdrop" id="bkBackdrop" onclick="bkCloseDrawer()"></div>
    <div class="bk-drawer" id="bkDrawer">
        <div class="bk-drawer__head">
            <div>
                <div style="font-size:18px;font-weight:800;" id="bkdMember">-</div>
                <div style="font-size:12px;color:var(--muted);margin-top:4px;" id="bkdStatus">-</div>
            </div>
            <button type="button" class="bk-drawer__close" onclick="bkCloseDrawer()">&times;</button>
        </div>
        <div class="bk-drawer__row"><span class="lbl">Personal Trainer</span><span class="val" id="bkdCoach">-</span></div>
        <div class="bk-drawer__row"><span class="lbl">Tanggal</span><span class="val" id="bkdDate">-</span></div>
        <div class="bk-drawer__row"><span class="lbl">Waktu</span><span class="val" id="bkdTime">-</span></div>
        <div class="bk-drawer__row"><span class="lbl">Lokasi</span><span class="val" id="bkdLocation">-</span></div>
        <div class="bk-drawer__row"><span class="lbl">Catatan Member</span><span class="val" id="bkdNote">-</span></div>
        <div class="bk-drawer__actions" id="bkdActions"></div>
    </div>
    <div class="bk-loading" id="bookingLoading" hidden>Memuat booking...</div>

    <script>
        function bkToggleSwap(btn) {
            const menu = btn.parentElement.querySelector('.bk-swap-menu');
            const open = menu.classList.contains('is-open');
            document.querySelectorAll('.bk-swap-menu.is-open').forEach(m => m.classList.remove('is-open'));
            if (!open) menu.classList.add('is-open');
        }
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.bk-pt')) {
                document.querySelectorAll('.bk-swap-menu.is-open').forEach(m => m.classList.remove('is-open'));
            }
        });

        function bkOpenDrawer(row) {
            const d = row.dataset;
            document.getElementById('bkdMember').textContent = d.member;
            document.getElementById('bkdStatus').textContent = 'Status: ' + d.status;
            document.getElementById('bkdCoach').textContent = d.coach;
            document.getElementById('bkdDate').textContent = d.date;
            document.getElementById('bkdTime').textContent = d.time;
            document.getElementById('bkdLocation').textContent = d.location;
            document.getElementById('bkdNote').textContent = d.note;

            const actions = document.getElementById('bkdActions');
            actions.innerHTML = '';
            if (d.canConfirm === '1') {
                actions.appendChild(bkActionForm(d.confirmUrl, 'Konfirmasi', 'btn btn-primary', 'Konfirmasi booking ini?'));
            }

            document.getElementById('bkBackdrop').classList.add('is-open');
            document.getElementById('bkDrawer').classList.add('is-open');
        }
        const BK_CSRF = "{{ csrf_token() }}";
        document.querySelectorAll('[data-booking-navigation]').forEach(link => {
            link.addEventListener('click', () => { document.getElementById('bookingLoading').hidden = false; });
        });
        document.querySelectorAll('.bk-panel .adm-pager a').forEach(link => {
            link.addEventListener('click', () => { document.getElementById('bookingLoading').hidden = false; });
        });
        const BK_LIVE_PROGRESS_URL = @json($liveProgressUrl);
        let bkLiveRequest = null;

        function bkEscape(value) {
            const node = document.createElement('div');
            node.textContent = value ?? '';
            return node.innerHTML;
        }
        function bkRenderLiveProgress(items) {
            const container = document.getElementById('bkLiveProgress');
            if (!items.length) {
                container.innerHTML = '<div class="bk-live-state">Tidak ada sesi yang sedang berlangsung saat ini.</div>';
                return;
            }
            container.innerHTML = items.map(item => {
                const initial = (item.member_name || '?').trim().charAt(0).toUpperCase() || '?';
                const avatar = item.member_avatar_public_url
                    ? `<img src="${bkEscape(item.member_avatar_public_url)}" alt="Avatar ${bkEscape(item.member_name)}" style="width:100%;height:100%;object-fit:cover;border-radius:50%;">`
                    : bkEscape(initial);
                const sessionNumber = item.session_number ? `<span>SESSION: #${String(item.session_number).padStart(2, '0')}</span>` : '';
                const sessionName = `${bkEscape(item.program_name || '-')} · ${bkEscape(item.session_name || '-')}`;
                const setSummary = `${Number(item.completed_sets || 0)}/${Number(item.total_sets || 0)} set selesai · ${Number(item.completed_exercises || 0)}/${Number(item.total_exercises || 0)} latihan`;
                return `<div class="bk-live-card"><div class="bk-live-card__head"><div class="bk-avatar" style="width:44px;height:44px;">${avatar}</div><div><div class="bk-live-card__name">${bkEscape(item.member_name)}</div><div class="bk-live-card__coach">With Coach ${bkEscape(item.coach_name)}</div></div></div><div class="bk-live-prog"><span class="bk-live-prog__label">Training Progress</span><span class="bk-live-prog__pct">${Number(item.progress)}%</span></div><div class="bk-live-track"><div class="bk-live-fill" style="width:${Number(item.progress)}%;"></div></div><div class="bk-live-session">${sessionName}</div><div class="bk-live-meta"><span>SEDANG BERJALAN</span>${sessionNumber}</div><div class="bk-live-sets">${setSummary}</div></div>`;
            }).join('');
        }
        async function bkRefreshLiveProgress(showLoading = false) {
            const container = document.getElementById('bkLiveProgress');
            if (bkLiveRequest) bkLiveRequest.abort();
            bkLiveRequest = new AbortController();
            if (showLoading) container.innerHTML = '<div class="bk-live-state">Memuat sesi berlangsung...</div>';
            try {
                const response = await fetch(BK_LIVE_PROGRESS_URL, { headers: { Accept: 'application/json' }, signal: bkLiveRequest.signal });
                if (!response.ok) throw new Error('Request failed');
                const payload = await response.json();
                bkRenderLiveProgress(payload.data || []);
            } catch (error) {
                if (error.name === 'AbortError') return;
                container.innerHTML = '<div class="bk-live-state">Live Progress gagal dimuat.<br><button type="button" class="btn btn-secondary" onclick="bkRefreshLiveProgress(true)">Coba Lagi</button></div>';
            }
        }
        window.setInterval(() => { if (!document.hidden) bkRefreshLiveProgress(false); }, 12000);
        function bkActionForm(url, label, cls, confirmMsg) {
            const form = document.createElement('form');
            form.method = 'POST'; form.action = url; form.style.margin = '0';
            form.onsubmit = () => confirm(confirmMsg);

            const token = document.createElement('input');
            token.type = 'hidden'; token.name = '_token'; token.value = BK_CSRF;
            const method = document.createElement('input');
            method.type = 'hidden'; method.name = '_method'; method.value = 'PATCH';
            const btn = document.createElement('button');
            btn.type = 'submit'; btn.className = cls; btn.textContent = label;

            form.appendChild(token);
            form.appendChild(method);
            form.appendChild(btn);
            return form;
        }
        function bkCloseDrawer() {
            document.getElementById('bkBackdrop').classList.remove('is-open');
            document.getElementById('bkDrawer').classList.remove('is-open');
        }
        document.addEventListener('keydown', (e) => { if (e.key === 'Escape') bkCloseDrawer(); });
    </script>
@endsection
