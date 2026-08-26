@extends('admin.layouts.app')

@php
    $title = 'Jadwal ' . ($user?->name ?? 'Trainer') . ' - EggGym Admin';
    $pageHeading = 'Jadwal Trainer';
    $pageSubheading = 'Jadwal sesi latihan aktual selama satu bulan.';
    $dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    $fullDayNames = [1 => 'Senin', 2 => 'Selasa', 3 => 'Rabu', 4 => 'Kamis', 5 => 'Jumat', 6 => 'Sabtu', 7 => 'Minggu'];
    $monthNames = [1 => 'Januari', 2 => 'Februari', 3 => 'Maret', 4 => 'April', 5 => 'Mei', 6 => 'Juni', 7 => 'Juli', 8 => 'Agustus', 9 => 'September', 10 => 'Oktober', 11 => 'November', 12 => 'Desember'];
    $avatar = $user?->avatar_url;
    $avatarSrc = $avatar ? (\Illuminate\Support\Str::startsWith($avatar, ['http://', 'https://']) ? $avatar : asset('storage/' . ltrim($avatar, '/'))) : null;
    $initial = mb_strtoupper(mb_substr($user?->name ?? 'T', 0, 1));
    $isActive = ($user?->status ?? 'inactive') === 'active';
@endphp

@section('content')
    <style>
        .ts-page { display:flex; flex-direction:column; gap:18px; }
        .ts-head { display:flex; align-items:center; justify-content:space-between; gap:16px; flex-wrap:wrap; }
        .ts-crumb { color:var(--muted); font-size:12px; }
        .ts-head__actions { display:flex; align-items:center; gap:8px; flex-wrap:wrap; }
        .ts-month-nav { display:flex; align-items:center; gap:7px; }
        .ts-month-label { min-width:128px; text-align:center; color:#fff; font-size:14px; font-weight:900; }
        .ts-arrow { width:36px; height:36px; padding:0; }
        .ts-summary { display:flex; align-items:center; justify-content:space-between; gap:18px; padding:18px 20px; flex-wrap:wrap; }
        .ts-profile { display:flex; align-items:center; gap:14px; min-width:0; }
        .ts-avatar { width:64px; height:64px; border-radius:13px; overflow:hidden; background:var(--panel-soft); display:flex; align-items:center; justify-content:center; color:var(--accent); font-size:24px; font-weight:900; flex-shrink:0; }
        .ts-avatar img { width:100%; height:100%; object-fit:cover; }
        .ts-name { color:#fff; font-size:18px; font-weight:900; }
        .ts-meta { margin-top:5px; color:var(--muted); font-size:11px; line-height:1.55; }
        .ts-counts { display:flex; gap:10px; flex-wrap:wrap; }
        .ts-count { min-width:120px; padding:12px 14px; border:1px solid var(--border); border-radius:10px; background:var(--bg); }
        .ts-count strong { display:block; color:var(--accent); font-size:19px; }
        .ts-count span { color:var(--muted); font-size:9px; text-transform:uppercase; letter-spacing:.8px; }
        .ts-calendar-panel,.ts-agenda-panel { padding:20px; }
        .ts-section-head { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:16px; }
        .ts-section-title { color:#fff; font-size:14px; font-weight:900; text-transform:uppercase; letter-spacing:.8px; }
        .ts-readonly { color:var(--accent); font-size:9px; font-weight:800; letter-spacing:1px; text-transform:uppercase; }
        .ts-legend { display:flex; align-items:center; gap:10px 16px; flex-wrap:wrap; margin-bottom:14px; }
        .ts-legend__item { display:flex; align-items:center; gap:7px; color:var(--muted); font-size:9px; font-weight:700; text-transform:uppercase; letter-spacing:.5px; }
        .ts-legend__dot { width:10px; height:10px; border-radius:3px; background:#555; }
        .ts-legend__dot.is-available { background:#22c55e; }
        .ts-legend__dot.is-booked { background:#f59e0b; }
        .ts-legend__dot.is-hold { background:#3b82f6; }
        .ts-legend__dot.is-unavailable { background:#656565; }
        .ts-calendar { display:grid; grid-template-columns:repeat(7,minmax(0,1fr)); border-top:1px solid var(--border); border-left:1px solid var(--border); }
        .ts-weekday { padding:10px 6px; border-right:1px solid var(--border); border-bottom:1px solid var(--border); color:var(--muted); font-size:9px; font-weight:800; text-align:center; text-transform:uppercase; }
        .ts-day { min-height:126px; padding:8px; border-right:1px solid var(--border); border-bottom:1px solid var(--border); background:var(--bg); overflow:hidden; }
        .ts-day.is-outside { background:#111; opacity:.45; }
        .ts-day.is-off { background:#151515; }
        .ts-day.is-today .ts-date-number { background:var(--accent); color:#111; }
        .ts-date-number { width:25px; height:25px; display:flex; align-items:center; justify-content:center; border-radius:50%; color:#ddd7ca; font-size:10px; font-weight:800; }
        .ts-day-items { margin-top:6px; display:flex; flex-direction:column; gap:5px; }
        .ts-session-mini { width:100%; border:1px solid #3d3d3d; border-radius:6px; background:var(--panel); padding:6px; color:#ddd7ca; text-align:left; cursor:pointer; overflow:hidden; }
        .ts-session-mini:hover { filter:brightness(1.12); }
        .ts-session-mini.is-available { border-color:rgba(34,197,94,.48); background:rgba(34,197,94,.11); }
        .ts-session-mini.is-available strong { color:#22c55e; }
        .ts-session-mini.is-booked { border-color:rgba(245,158,11,.5); background:rgba(245,158,11,.11); }
        .ts-session-mini.is-booked strong { color:#f59e0b; }
        .ts-session-mini.is-reschedule_pending { border-color:rgba(59,130,246,.5); background:rgba(59,130,246,.12); }
        .ts-session-mini.is-reschedule_pending strong { color:#60a5fa; }
        .ts-session-mini.is-unavailable { border-color:#3c3c3c; background:#242424; color:#817b70; }
        .ts-session-mini.is-unavailable strong { color:#888; }
        .ts-session-mini strong,.ts-session-mini span { display:block; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .ts-session-mini strong { color:var(--accent); font-size:9px; }
        .ts-session-mini span { margin-top:2px; font-size:9px; }
        .ts-more { color:var(--muted); font-size:9px; font-weight:700; padding-left:3px; }
        .ts-off-label { margin-top:14px; color:#626262; font-size:9px; font-weight:800; text-align:center; text-transform:uppercase; letter-spacing:.8px; }
        .ts-agenda { display:flex; flex-direction:column; gap:18px; }
        .ts-date-group { display:flex; flex-direction:column; gap:8px; }
        .ts-date-heading { color:var(--accent); font-size:10px; font-weight:900; letter-spacing:1px; text-transform:uppercase; }
        .ts-agenda-item { width:100%; display:grid; grid-template-columns:115px 1fr auto; gap:14px; align-items:center; padding:13px 15px; border:1px solid var(--border); border-radius:10px; background:var(--bg); color:inherit; text-align:left; cursor:pointer; }
        .ts-agenda-item:hover { border-color:rgba(250,204,21,.45); }
        .ts-time { color:#fff; font-size:12px; font-weight:900; }
        .ts-time small { display:block; margin-top:4px; color:var(--muted); font-size:9px; font-weight:500; }
        .ts-client { color:#ddd7ca; font-size:12px; font-weight:800; }
        .ts-client small { display:block; margin-top:4px; color:var(--muted); font-size:10px; font-weight:500; }
        .ts-badges { display:flex; gap:6px; flex-wrap:wrap; justify-content:flex-end; }
        .ts-badge { padding:5px 8px; border-radius:999px; border:1px solid #464646; color:#bbb4a8; font-size:8px; font-weight:800; text-transform:uppercase; white-space:nowrap; }
        .ts-badge.is-completed { color:#22c55e; border-color:rgba(34,197,94,.35); }
        .ts-badge.is-cancelled { color:#ef4444; border-color:rgba(239,68,68,.35); }
        .ts-badge.is-pending { color:#f59e0b; border-color:rgba(245,158,11,.4); }
        .ts-empty { padding:38px 20px; border:1px dashed var(--border); border-radius:10px; text-align:center; color:#ddd7ca; }
        .ts-empty span { display:block; margin-top:7px; color:var(--muted); font-size:11px; }
        .ts-dialog { width:min(520px,calc(100% - 30px)); border:1px solid var(--border); border-radius:13px; background:var(--panel); color:#fff; padding:0; box-shadow:0 24px 70px rgba(0,0,0,.65); }
        .ts-dialog::backdrop { background:rgba(0,0,0,.72); }
        .ts-dialog__head { display:flex; justify-content:space-between; align-items:center; padding:18px 20px; border-bottom:1px solid var(--border); }
        .ts-dialog__head strong { color:var(--accent); font-size:13px; }
        .ts-dialog__close { border:0; background:transparent; color:var(--muted); font-size:24px; cursor:pointer; }
        .ts-dialog__body { padding:18px 20px; display:grid; grid-template-columns:1fr 1fr; gap:11px; }
        .ts-loading { position:fixed; inset:0; z-index:1200; display:flex; align-items:center; justify-content:center; background:rgba(8,8,8,.72); backdrop-filter:blur(3px); color:var(--accent); font-size:12px; font-weight:900; letter-spacing:1px; text-transform:uppercase; }
        .ts-loading[hidden] { display:none; }
        .ts-detail { padding:11px; border-radius:8px; background:var(--bg); border:1px solid var(--border); }
        .ts-detail.is-wide { grid-column:1 / -1; }
        .ts-detail label { display:block; color:var(--muted); font-size:8px; text-transform:uppercase; letter-spacing:.8px; }
        .ts-detail div { margin-top:5px; color:#ddd7ca; font-size:11px; line-height:1.45; }
        @media(max-width:900px){ .ts-calendar-panel{overflow-x:auto;} .ts-calendar{min-width:760px;} .ts-agenda-item{grid-template-columns:100px 1fr;} .ts-badges{grid-column:1 / -1; justify-content:flex-start;} }
        @media(max-width:600px){ .ts-head__actions{width:100%;} .ts-summary{align-items:flex-start;} .ts-counts{width:100%;} .ts-count{flex:1;} .ts-agenda-item{grid-template-columns:1fr;} .ts-badges{grid-column:auto;} .ts-dialog__body{grid-template-columns:1fr;} .ts-detail.is-wide{grid-column:auto;} }
    </style>

    <div class="ts-page">
        <header class="ts-head">
            <div class="ts-crumb">Personal Trainer / {{ $user?->name ?? 'Trainer' }} / Jadwal</div>
            <div class="ts-head__actions">
                <a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Kembali</a>
                <nav class="ts-month-nav" aria-label="Navigasi bulan jadwal">
                    <a href="{{ route('admin.trainer-profiles.schedule', ['trainerProfile' => $trainer, 'month' => $previousMonth]) }}" class="btn btn-secondary ts-arrow" data-month-navigation aria-label="Bulan sebelumnya">&larr;</a>
                    <span class="ts-month-label">{{ $monthLabel }}</span>
                    <a href="{{ route('admin.trainer-profiles.schedule', ['trainerProfile' => $trainer, 'month' => $nextMonth]) }}" class="btn btn-secondary ts-arrow" data-month-navigation aria-label="Bulan berikutnya">&rarr;</a>
                </nav>
                @if ($month->format('Y-m') !== $currentMonth)
                    <a href="{{ route('admin.trainer-profiles.schedule', ['trainerProfile' => $trainer, 'month' => $currentMonth]) }}" class="btn btn-primary" data-month-navigation>Bulan Ini</a>
                @endif
            </div>
        </header>

        <section class="panel ts-summary">
            <div class="ts-profile">
                <div class="ts-avatar">@if($avatarSrc)<img src="{{ $avatarSrc }}" alt="Avatar {{ $user?->name }}">@else{{ $initial }}@endif</div>
                <div><div class="ts-name">{{ $user?->name ?? 'Trainer' }}</div><div class="ts-meta">{{ collect($trainer->specialty_labels)->join(' • ') ?: 'Spesialisasi belum diisi' }}<br>Akun {{ $isActive ? 'Aktif' : 'Nonaktif' }} • {{ $timezone }}</div></div>
            </div>
            <div class="ts-counts">
                <div class="ts-count"><strong>{{ $activeSessionCount }}</strong><span>Sesi aktif pada {{ $monthLabel }}</span></div>
                <div class="ts-count"><strong>{{ $cancelledSessionCount }}</strong><span>Dibatalkan / dilepas</span></div>
            </div>
        </section>

        <section class="panel ts-calendar-panel">
            <div class="ts-section-head"><div class="ts-section-title">Kalender Sesi Aktual</div><div class="ts-readonly">Hanya Lihat</div></div>
            <div class="ts-legend" aria-label="Legenda status jadwal">
                <div class="ts-legend__item"><span class="ts-legend__dot is-available"></span>Tersedia / Kosong</div>
                <div class="ts-legend__item"><span class="ts-legend__dot is-booked"></span>Sudah Dibooking</div>
                <div class="ts-legend__item"><span class="ts-legend__dot is-hold"></span>Reschedule Pending</div>
                <div class="ts-legend__item"><span class="ts-legend__dot is-unavailable"></span>Tidak Aktif / Tidak Tersedia</div>
            </div>
            <div class="ts-calendar">
                @foreach($dayNames as $dayName)<div class="ts-weekday">{{ $dayName }}</div>@endforeach
                @foreach($calendarDates as $date)
                    @php
                        $dateKey = $date->toDateString();
                        $daySlots = $slotsByDate->get($dateKey, collect());
                        $isOff = $date->month === $month->month && $dayStates->get($dateKey) === 'off';
                    @endphp
                    <div class="ts-day {{ $date->month !== $month->month ? 'is-outside' : '' }} {{ $isOff ? 'is-off' : '' }} {{ $dateKey === now($timezone)->toDateString() ? 'is-today' : '' }}" @if($date->month === $month->month) role="button" tabindex="0" data-date="{{ $dateKey }}" data-slots='@json($daySlots, JSON_HEX_APOS | JSON_HEX_QUOT)' onclick="tsOpenDay(this)" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();tsOpenDay(this);}" @endif>
                        <div class="ts-date-number">{{ $date->day }}</div>
                        @if($date->month === $month->month && $daySlots->isNotEmpty())
                            <div class="ts-day-items">
                                @foreach($daySlots->take(2) as $slot)
                                    @php
                                        $slotLabel = match($slot['slot_state']) {
                                            'available' => 'Kosong',
                                            'booked' => $slot['member_name'] ?? 'Dibooking',
                                            'reschedule_pending' => 'Reschedule Pending',
                                            default => 'Tidak tersedia',
                                        };
                                    @endphp
                                    <button type="button" class="ts-session-mini is-{{ $slot['slot_state'] }}" data-session='@json($slot, JSON_HEX_APOS | JSON_HEX_QUOT)' onclick="event.stopPropagation();tsOpenSession(this)"><strong>{{ $slot['slot_start_time'] }}–{{ $slot['slot_end_time'] }}</strong><span>{{ $slotLabel }}</span></button>
                                @endforeach
                                @if($daySlots->count() > 2)<div class="ts-more">+{{ $daySlots->count() - 2 }} slot lainnya</div>@endif
                            </div>
                        @elseif($isOff)
                            <div class="ts-off-label">Off</div>
                        @endif
                    </div>
                @endforeach
            </div>
        </section>

        <section class="panel ts-agenda-panel">
            <div class="ts-section-head"><div class="ts-section-title">Agenda {{ $monthLabel }}</div><div class="ts-readonly">{{ $sessions->count() }} sesi tercatat</div></div>
            @if($sessions->isEmpty())
                <div class="ts-empty">Belum ada jadwal sesi pada bulan ini.<span>Pilih bulan lain untuk melihat jadwal trainer.</span></div>
            @else
                <div class="ts-agenda">
                    @foreach($sessionsByDate as $dateKey => $dateSessions)
                        @php $date = \Carbon\CarbonImmutable::parse($dateKey, $timezone); @endphp
                        <div class="ts-date-group">
                            <div class="ts-date-heading">{{ $fullDayNames[$date->dayOfWeekIso] }}, {{ $date->day }} {{ $monthNames[$date->month] }} {{ $date->year }}</div>
                            @foreach($dateSessions as $session)
                                @php $statusLabel = $statusLabels[$session['status']] ?? \Illuminate\Support\Str::headline($session['status']); $statusClass = in_array($session['status'], ['cancelled','released','expired','rejected'], true) ? 'is-cancelled' : ($session['status'] === 'completed' ? 'is-completed' : ($session['has_pending_reschedule'] ? 'is-pending' : '')); @endphp
                                <button type="button" class="ts-agenda-item" data-session='@json($session, JSON_HEX_APOS | JSON_HEX_QUOT)' onclick="tsOpenSession(this)">
                                    <div class="ts-time">{{ $session['start_time'] }}–{{ $session['end_time'] }}<small>WIB</small></div>
                                    <div class="ts-client">{{ $session['member_name'] }}<small>{{ $session['title'] }}{{ $session['program_title'] ? ' • ' . $session['program_title'] : '' }}</small></div>
                                    <div class="ts-badges"><span class="ts-badge {{ $statusClass }}">{{ $statusLabel }}</span>@if($session['has_pending_reschedule'])<span class="ts-badge is-pending">Reschedule Pending</span>@endif</div>
                                </button>
                            @endforeach
                        </div>
                    @endforeach
                </div>
            @endif
        </section>
    </div>

    <dialog class="ts-dialog" id="sessionDialog">
        <div class="ts-dialog__head"><strong>Detail Sesi</strong><button type="button" class="ts-dialog__close" onclick="document.getElementById('sessionDialog').close()" aria-label="Tutup">&times;</button></div>
        <div class="ts-dialog__body" id="sessionDialogBody"></div>
    </dialog>
    <dialog class="ts-dialog" id="dayDialog">
        <div class="ts-dialog__head"><strong id="dayDialogTitle">Detail Slot</strong><button type="button" class="ts-dialog__close" onclick="document.getElementById('dayDialog').close()" aria-label="Tutup">&times;</button></div>
        <div class="ts-dialog__body" id="dayDialogBody"></div>
    </dialog>
    <div class="ts-loading" id="scheduleLoading" hidden>Memuat jadwal...</div>

    <script>
        const tsStatusLabels = @json($statusLabels);
        document.querySelectorAll('[data-month-navigation]').forEach(link => {
            link.addEventListener('click', () => { document.getElementById('scheduleLoading').hidden = false; });
        });
        function tsEscape(value) { const node = document.createElement('div'); node.textContent = value ?? '-'; return node.innerHTML; }
        function tsOpenSession(button) {
            const session = JSON.parse(button.dataset.session);
            const fields = [
                ['Tanggal', session.date ? session.date.substring(0, 10) : '-'],
                ['Waktu', `${session.start_time}–${session.end_time} WIB`],
                ['Member', session.member_name],
                ['Sesi', session.title],
                ['Program', session.program_title || '-'],
                ['Nomor Sesi', session.sequence_order ? `Sesi ${session.sequence_order}` : '-'],
                ['Status', tsStatusLabels[session.status] || session.status],
                ['Status Pembayaran', session.payment_status || '-'],
                ['Lokasi', session.location || '-'],
                ['Reschedule', session.has_pending_reschedule ? 'Menunggu persetujuan; jadwal aktif belum berubah.' : '-'],
            ];
            document.getElementById('sessionDialogBody').innerHTML = fields.map(([label,value]) => `<div class="ts-detail"><label>${tsEscape(label)}</label><div>${tsEscape(String(value))}</div></div>`).join('');
            document.getElementById('sessionDialog').showModal();
        }
        function tsOpenDay(cell) {
            const slots = JSON.parse(cell.dataset.slots || '[]');
            const date = cell.dataset.date;
            document.getElementById('dayDialogTitle').textContent = `Slot ${date}`;
            const body = document.getElementById('dayDialogBody');
            if (!slots.length) {
                body.innerHTML = '<div class="ts-detail is-wide"><label>Status Hari</label><div>Off / tidak ada jadwal aktif.</div></div>';
            } else {
                body.innerHTML = slots.map(slot => {
                    const labels = { available: 'Kosong / Tersedia', booked: `Dibooking oleh ${slot.member_name || 'member'}`, reschedule_pending: `Reschedule Pending${slot.member_name ? ' - ' + slot.member_name : ''}`, unavailable: 'Tidak tersedia' };
                    return `<button type="button" class="ts-detail is-wide" style="text-align:left;cursor:pointer;color:inherit;" data-session='${tsEscape(JSON.stringify(slot))}' onclick="document.getElementById('dayDialog').close();tsOpenSession(this)"><label>${tsEscape(slot.slot_start_time)}–${tsEscape(slot.slot_end_time)}</label><div>${tsEscape(labels[slot.slot_state] || slot.slot_state)}</div></button>`;
                }).join('');
            }
            document.getElementById('dayDialog').showModal();
        }
    </script>
@endsection
