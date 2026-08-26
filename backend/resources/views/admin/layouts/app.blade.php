<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $title ?? 'EggGym Admin' }}</title>
    <link rel="icon" href="{{ $appBranding['logo_path'] ? asset('storage/'.$appBranding['logo_path']).'?v='.$appBranding['logo_version'] : asset('favicon.ico') }}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            color-scheme: dark;
            /* ============================================================
               Design tokens &mdash; SINGLE SOURCE OF TRUTH (warna dari Figma asli)
               Background = ABU GELAP NETRAL murni (bukan olive/coklat).
               Kuning HANYA aksen (teks penting, CTA, badge, border aktif).
               ============================================================ */
            --bg: #131313;              /* background utama halaman (netral) */
            --panel: #201F1F;           /* background card/panel */
            --panel-soft: #2A2A2A;      /* card alternatif / hover */
            --border: #353534;          /* border default (abu netral) */
            --border-muted: rgba(77, 71, 50, 0.25); /* border tipis halus (satu-satunya olive, subtle) */
            --sidebar-bg: #0F0F0F;      /* sidebar sedikit lebih gelap dari bg */
            --text: #FFFFFF;            /* teks utama / judul */
            --text-secondary: #E5E2E1;  /* teks sekunder (off-white) */
            --muted: #9CA3AF;           /* label / caption / teks pudar */
            --text-muted: #6B7280;      /* teks nonaktif / disabled */
            --accent: #FACC15;          /* kuning aksen (CTA, angka penting, badge/border aktif) */
            --accent-hover: #EAB308;    /* hover aksen */
            --accent-tint: rgba(250, 204, 21, 0.15); /* background badge/highlight redup */
            --on-accent: #131313;       /* teks di atas elemen kuning */
            --danger: #EF4444;          /* merah &mdash; nonaktif/gagal/expired */
            --success: #22C55E;         /* hijau &mdash; aktif/sukses */
            --warning: #F59E0B;
            --info: #3B82F6;
            --overlay-dark: rgba(0,0,0,0.4);   /* modal backdrop */
            --overlay-light: rgba(255,255,255,0.06); /* hover highlight halus */
            --shadow-card: 0 2px 8px rgba(0,0,0,0.4);
            --shadow-hover: 0 8px 20px rgba(0,0,0,0.6);
            --shadow-button: 0 2px 8px rgba(250,204,21,0.35);
        }

        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: "Inter", "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg);
            color: var(--text);
        }
        a { color: inherit; text-decoration: none; }
        .layout {
            display: grid;
            grid-template-columns: 260px 1fr;
            min-height: 100vh;
        }
        .sidebar {
            background: var(--sidebar-bg);
            border-right: 1px solid var(--border);
            padding: 24px 18px;
            display: flex;
            flex-direction: column;
        }
        .brand {
            display: flex;
            align-items: center;
            gap: 11px;
            min-height: 48px;
            margin-bottom: 20px;
        }
        .brand__text {
            min-width: 0;
        }
        .brand h1 {
            margin: 0;
            font-size: 20px;
            font-weight: 800;
            line-height: 1.05;
            color: var(--accent);
        }
        .brand__logo { width: 48px; height: 48px; flex: 0 0 48px; object-fit: contain; border-radius: 9px; }
        .brand p {
            margin: 4px 0 0;
            color: var(--muted);
            line-height: 1.1;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 1.2px;
        }
        .nav-group {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        .nav-link {
            padding: 11px 14px;
            border-radius: 10px;
            color: var(--muted);
            border-left: 3px solid transparent;
            font-size: 13px;
            font-weight: 600;
            transition: color 0.2s ease, background 0.2s ease;
        }
        .nav-link:hover {
            color: var(--accent);
            background: var(--panel-soft);
        }
        .nav-link.active {
            color: var(--accent);
            background: var(--panel);
            border-left-color: var(--accent);
            font-weight: 700;
        }
        .content {
            padding: 28px;
        }
        .topbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
        }
        .topbar h2 {
            margin: 0;
            font-size: 26px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }
        .topbar p {
            margin: 8px 0 0;
            color: var(--muted);
            font-size: 13px;
        }
        .panel {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 24px;
            box-shadow: var(--shadow-card);
        }
        .flash {
            margin-bottom: 18px;
            padding: 14px 16px;
            border-radius: 10px;
            background: rgba(76, 175, 80, 0.12);
            border: 1px solid rgba(76, 175, 80, 0.3);
            color: #cdeed7;
        }
        .flash[data-auto-dismiss] {
            transition: opacity 0.25s ease, transform 0.25s ease, margin 0.25s ease, padding 0.25s ease;
        }
        .flash.is-dismissing {
            opacity: 0; transform: translateY(-6px); margin-bottom: 0; padding-top: 0;
            padding-bottom: 0; border-width: 0; overflow: hidden;
        }
        .grid {
            display: grid;
            gap: 20px;
        }
        .grid-4 {
            grid-template-columns: repeat(4, minmax(0, 1fr));
        }
        .stat-card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 20px;
            box-shadow: var(--shadow-card);
            transition: border-color 0.2s ease, box-shadow 0.2s ease;
        }
        .stat-card:hover {
            border-color: var(--accent);
            box-shadow: var(--shadow-hover);
        }
        .stat-card small {
            color: var(--muted);
            display: block;
            margin-bottom: 10px;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
        }
        .stat-card strong {
            font-size: 32px;
            font-weight: 800;
            color: var(--accent);
        }
        .stat-card--accent {
            background: var(--accent);
            border-color: var(--accent);
            box-shadow: var(--shadow-button);
        }
        .stat-card--accent small {
            color: rgba(26, 21, 0, 0.7);
        }
        .stat-card--accent strong {
            color: var(--on-accent);
        }
        .stat-card--accent:hover {
            border-color: var(--accent);
            box-shadow: var(--shadow-hover);
        }
        .actions {
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            border: 1px solid transparent;
            border-radius: 8px;
            padding: 10px 16px;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            transition: background 0.2s ease, transform 0.15s ease, border-color 0.2s ease;
        }
        .btn-primary {
            background: var(--accent);
            color: var(--on-accent);
            box-shadow: var(--shadow-button);
        }
        .btn-primary:hover {
            background: var(--accent-hover);
            transform: translateY(-1px);
        }
        .btn-secondary {
            background: var(--panel-soft);
            border-color: var(--border);
            color: var(--text);
        }
        .btn-secondary:hover {
            border-color: var(--accent);
            color: var(--accent);
        }
        .btn-danger {
            background: transparent;
            color: var(--danger);
            border-color: rgba(239, 68, 68, 0.35);
        }
        .btn-danger:hover {
            background: rgba(239, 68, 68, 0.12);
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            text-align: left;
            padding: 14px 12px;
            border-bottom: 1px solid var(--border);
            vertical-align: top;
        }
        th {
            color: var(--muted);
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
        }
        .badge {
            display: inline-flex;
            align-items: center;
            padding: 5px 12px;
            border-radius: 999px;
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }
        .badge-active {
            background: rgba(76, 175, 80, 0.15);
            border: 1px solid rgba(76, 175, 80, 0.5);
            color: #7fd99a;
        }
        .badge-inactive {
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.5);
            color: #f2a3a3;
        }
        .form-grid {
            display: grid;
            gap: 16px;
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }
        .field {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .field-full {
            grid-column: 1 / -1;
        }
        label {
            font-weight: 700;
        }
        input, textarea, select {
            width: 100%;
            padding: 12px 14px;
            border-radius: 12px;
            border: 1px solid var(--border);
            background: var(--panel-soft);
            color: var(--text);
            font: inherit;
        }
        textarea {
            min-height: 120px;
            resize: vertical;
        }
        .error {
            color: #ffc3c3;
            font-size: 13px;
        }
        .help {
            color: var(--muted);
            font-size: 13px;
            line-height: 1.5;
        }
        .pagination {
            display: flex;
            gap: 8px;
            margin-top: 18px;
        }
        .pagination a,
        .pagination span {
            padding: 8px 12px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: var(--panel-soft);
            color: var(--text);
        }
        /* Reusable pagination footer (admin/partials/pagination) */
        .adm-pager-foot {
            display: flex; align-items: center; justify-content: space-between;
            gap: 12px; min-height: 48px; padding: 10px 20px;
            border-top: 1px solid var(--border); background: var(--panel);
            border-radius: 0 0 10px 10px; flex-wrap: wrap;
        }
        .adm-pager-foot__info { font-size: 12px; color: var(--muted); }
        .adm-pager { display: flex; align-items: center; gap: 6px; }
        .adm-pager__page, .adm-pager__nav {
            display: inline-flex; align-items: center; justify-content: center;
            min-width: 32px; height: 32px; padding: 0 10px; border-radius: 6px;
            font-size: 13px; font-weight: 600; color: var(--muted);
            background: var(--panel); border: 1px solid var(--border);
            text-decoration: none; transition: all 0.15s ease;
        }
        .adm-pager__page:hover, .adm-pager__nav:hover { border-color: var(--accent); color: var(--accent); }
        .adm-pager__page.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
        .adm-pager__nav { font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
        .adm-pager__nav.is-disabled { opacity: 0.45; cursor: not-allowed; }
        .adm-pager__ellipsis { color: var(--text-muted); padding: 0 2px; font-size: 13px; }
        /* Sidebar grouping */
        .nav-scroll { flex: 1; overflow-y: auto; }
        .nav-group-label {
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 2px;
            text-transform: uppercase;
            color: var(--text-muted);
            padding: 0 14px;
            margin: 18px 0 8px;
        }
        .nav-group-label:first-child { margin-top: 0; }
        /* Sidebar profile (bottom) */
        .sidebar-profile {
            margin-top: 16px;
            padding-top: 16px;
            border-top: 1px solid var(--border);
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .sidebar-profile__avatar {
            width: 40px; height: 40px; border-radius: 50%;
            background: var(--accent); color: var(--on-accent);
            display: flex; align-items: center; justify-content: center;
            font-weight: 800; font-size: 15px; flex-shrink: 0;
        }
        .sidebar-profile__name { font-size: 14px; font-weight: 700; color: var(--text); }
        .sidebar-profile__role { font-size: 10px; font-weight: 600; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); }
        /* Header bar */
        .topbar__title {
            font-size: 18px; font-weight: 800; letter-spacing: 2px;
            text-transform: uppercase; color: var(--accent); margin: 0;
        }
        .topbar__search {
            flex: 1; max-width: 340px; margin: 0 20px;
            display: flex; align-items: center; gap: 8px;
            background: var(--panel-soft); border: 1px solid var(--border);
            border-radius: 8px; padding: 0 12px; height: 40px;
        }
        .topbar__search button {
            border: 0; background: transparent; color: var(--accent); cursor: pointer;
            font-size: 12px; font-weight: 700; padding: 0;
        }
        .topbar__search input {
            border: 0; background: transparent; padding: 0; height: 100%;
            border-radius: 0; color: var(--text); font-size: 13px;
        }
        .topbar__search input:focus { outline: none; }
        .topbar__search-icon { color: var(--text-muted); font-size: 15px; }
        .topbar__actions { display: flex; align-items: center; gap: 14px; }
        .topbar__icon {
            width: 38px; height: 38px; border-radius: 10px; border: 1px solid var(--border);
            background: var(--panel-soft); color: var(--muted); display: flex;
            align-items: center; justify-content: center; font-size: 16px; cursor: pointer;
        }
        .topbar__notification { position: relative; }
        .topbar__notification-toggle { font: inherit; }
        .topbar__notification-badge { position:absolute; top:-5px; right:-5px; min-width:17px; height:17px; padding:0 4px; border-radius:999px; display:grid; place-items:center; background:#EF4444; color:#fff; border:2px solid var(--bg); font-size:9px; font-weight:800; }
        .topbar__notification-menu { display:none; position:absolute; z-index:30; top:46px; right:0; width:min(390px,calc(100vw - 32px)); padding:8px; border:1px solid var(--border); border-radius:12px; background:var(--panel); box-shadow:0 18px 45px rgba(0,0,0,.28); }
        .topbar__notification.is-open .topbar__notification-menu { display:block; }
        .topbar__notification-head { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:8px; }
        .topbar__notification-item { display:grid; grid-template-columns:1fr auto; gap:10px; align-items:center; padding:11px 9px; border-top:1px solid var(--border); color:var(--text); }
        .topbar__notification-item.is-unread { background:rgba(250,204,21,.06); }
        .topbar__notification-item.is-warning { border-left:3px solid var(--danger); background:rgba(239,68,68,.08); }
        .topbar__notification-title { font-size:12px; font-weight:800; }
        .topbar__notification-message { margin-top:3px; color:var(--muted); font-size:11px; line-height:1.35; }
        .topbar__notification-empty { padding:18px 9px; text-align:center; color:var(--muted); font-size:12px; }
        .topbar__icon:hover { color: var(--accent); border-color: var(--accent); }
        @media (max-width: 1080px) {
            .layout { grid-template-columns: 1fr; }
            .sidebar { border-right: 0; border-bottom: 1px solid var(--border); }
            .grid-4, .form-grid { grid-template-columns: 1fr; }
            .topbar__search { display: none; }
        }
    </style>
</head>
<body>
    <div class="layout">
        <aside class="sidebar">
            <div class="brand">
                @if($appBranding['logo_path'])<img class="brand__logo" src="{{ asset('storage/'.$appBranding['logo_path']) }}?v={{ $appBranding['logo_version'] }}" alt="Logo {{ $appBranding['name'] }}" onerror="this.hidden=true">@endif
                <div class="brand__text">
                    <h1>{{ $appBranding['name'] }}</h1>
                    <p>MANAGEMENT</p>
                </div>
            </div>

            <div class="nav-scroll">
                <nav class="nav-group">
                    <a class="nav-link {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}" href="{{ route('admin.dashboard') }}">Dashboard</a>
                    <a class="nav-link {{ request()->routeIs('admin.members.*') ? 'active' : '' }}" href="{{ route('admin.members.index') }}">Member</a>
                    <a class="nav-link {{ request()->routeIs('admin.member-progress.*') ? 'active' : '' }}" href="{{ route('admin.member-progress.index') }}">Physical Progress</a>
                    <a class="nav-link {{ request()->routeIs('admin.membership-plans.*') ? 'active' : '' }}" href="{{ route('admin.membership-plans.index') }}">Paket Membership</a>
                    <a class="nav-link {{ request()->routeIs('admin.trainer-profiles.*') ? 'active' : '' }}" href="{{ route('admin.trainer-profiles.index') }}">Personal Trainer</a>
                    <a class="nav-link {{ request()->routeIs('admin.bookings.*') ? 'active' : '' }}" href="{{ route('admin.bookings.index') }}">Booking & Sesi PT</a>
                    <a class="nav-link {{ request()->routeIs('admin.transactions.*') ? 'active' : '' }}" href="{{ route('admin.transactions.index') }}">Pembayaran</a>
                    <a class="nav-link {{ request()->routeIs('admin.equipments.*') ? 'active' : '' }}" href="{{ route('admin.equipments.index') }}">Alat Gym</a>
                    <a class="nav-link {{ request()->routeIs('admin.audit-trail.*') ? 'active' : '' }}" href="{{ route('admin.audit-trail.index') }}">Audit Trail</a>
                    <a class="nav-link {{ request()->routeIs('admin.reports.*') ? 'active' : '' }}" href="{{ route('admin.reports.index') }}">Laporan</a>
                    <a class="nav-link {{ request()->routeIs('admin.settings.*') || request()->routeIs('admin.operation-hours.*') || request()->routeIs('admin.admin-accounts.*') ? 'active' : '' }}" href="{{ route('admin.settings.index') }}">Pengaturan</a>
                </nav>
            </div>

            @php($adminUser = auth()->user())
            <div class="sidebar-profile">
                <div class="sidebar-profile__avatar">{{ strtoupper(mb_substr($adminUser->name ?? 'A', 0, 1)) }}</div>
                <div>
                    <div class="sidebar-profile__name">{{ $adminUser->name ?? 'Admin' }}</div>
                    <div class="sidebar-profile__role">{{ $adminUser?->is_admin_owner ? 'Admin Utama' : 'Admin' }}</div>
                </div>
            </div>
        </aside>

        <main class="content">
            <div class="topbar">
                @unless ($hideTopbarTitle ?? false)
                    <h2 class="topbar__title">{{ $pageHeading ?? 'Admin Web' }}</h2>
                @endunless
                @php($topbarSearchPlaceholders = [
                    'admin.members.index' => 'Cari nama, email, telepon, kode member...',
                    'admin.member-progress.index' => 'Cari member atau target kebugaran...',
                    'admin.membership-plans.index' => 'Cari paket, durasi, harga, status...',
                    'admin.trainer-profiles.index' => 'Cari trainer, specialty, tier, status...',
                    'admin.bookings.index' => 'Cari booking, member, PT, status, tanggal...',
                    'admin.transactions.index' => 'Cari transaksi, member, metode, status...',
                    'admin.equipments.index' => 'Cari alat, kategori, status, lokasi...',
                    'admin.admin-accounts.index' => 'Cari nama, email, atau status Admin...',
                    'admin.reports.index' => 'Cari paket atau performa trainer...',
                ])
                @php($topbarRouteName = request()->route()?->getName())
                @php($topbarSearchEnabled = array_key_exists($topbarRouteName, $topbarSearchPlaceholders))
                @if ($topbarSearchEnabled)
                    <form class="topbar__search" method="GET" action="{{ request()->url() }}" role="search">
                        @foreach (request()->except(['search', 'page']) as $key => $value)
                            @if (is_scalar($value))
                                <input type="hidden" name="{{ $key }}" value="{{ $value }}">
                            @endif
                        @endforeach
                        <span class="topbar__search-icon">&#128269;</span>
                        <input type="search" name="search" value="{{ request()->query('search', '') }}"
                            placeholder="{{ $topbarSearchPlaceholders[$topbarRouteName] }}" aria-label="Pencarian {{ $pageHeading ?? 'Admin' }}">
                        <button type="submit" aria-label="Jalankan pencarian">Cari</button>
                    </form>
                @endif
                <div class="topbar__actions">
                    <div class="topbar__notification" data-notification-menu>
                        <button type="button" class="topbar__icon topbar__notification-toggle" aria-expanded="false" aria-label="Notifikasi{{ $adminUnreadNotificationCount > 0 ? ': '.$adminUnreadNotificationCount.' belum dibaca' : '' }}">
                            &#128276;
                            @if($adminUnreadNotificationCount > 0)<span class="topbar__notification-badge">{{ $adminUnreadNotificationCount > 99 ? '99+' : $adminUnreadNotificationCount }}</span>@endif
                        </button>
                        <div class="topbar__notification-menu">
                            <div class="topbar__notification-head"><strong>Notifikasi terbaru</strong>@if($adminUnreadNotificationCount > 0)<form method="POST" action="{{ route('admin.notifications.read-all') }}">@csrf<button class="btn btn-secondary" type="submit">Baca semua</button></form>@endif</div>
                            @forelse($adminLatestNotifications as $notification)
                                <div class="topbar__notification-item {{ !$notification->is_read ? 'is-unread' : '' }} {{ $notification->priority === 'high' ? 'is-warning' : '' }}">
                                    <div><div class="topbar__notification-title">{{ $notification->title }}</div><div class="topbar__notification-message">{{ \Illuminate\Support\Str::limit($notification->message, 95) }}</div></div>
                                    <form method="POST" action="{{ route('admin.notifications.read', $notification->id) }}">@csrf<button class="btn btn-secondary" type="submit">{{ $notification->is_read ? 'Buka' : 'Baca' }}</button></form>
                                </div>
                            @empty
                                <div class="topbar__notification-empty">Notifikasi terbaru masih kosong.</div>
                            @endforelse
                            <a class="btn btn-secondary" style="display:flex;justify-content:center;margin:8px;" href="{{ route('admin.notifications.inbox') }}">Lihat semua notifikasi</a>
                        </div>
                    </div>
                    <form method="POST" action="{{ route('admin.logout') }}" style="margin: 0;">
                        @csrf
                        <button type="submit" class="btn btn-secondary">Logout</button>
                    </form>
                </div>
            </div>

            @if (session('success'))
                <div class="flash" data-auto-dismiss="4000" role="status">{{ session('success') }}</div>
            @endif

            @yield('content')
        </main>
    </div>
    <script>
        document.querySelectorAll('[data-notification-menu]').forEach((menu) => {
            const toggle = menu.querySelector('.topbar__notification-toggle');
            toggle.addEventListener('click', () => {
                const open = menu.classList.toggle('is-open');
                toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
            });
            document.addEventListener('click', (event) => {
                if (!menu.contains(event.target)) {
                    menu.classList.remove('is-open');
                    toggle.setAttribute('aria-expanded', 'false');
                }
            });
        });
        document.querySelectorAll('.flash[data-auto-dismiss]').forEach((flash) => {
            const delay = Number(flash.dataset.autoDismiss) || 4000;
            window.setTimeout(() => {
                flash.classList.add('is-dismissing');
                window.setTimeout(() => flash.remove(), 260);
            }, delay);
        });
    </script>
</body>
</html>
