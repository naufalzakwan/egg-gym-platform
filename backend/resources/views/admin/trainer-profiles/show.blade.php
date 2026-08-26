@extends('admin.layouts.app')

@php
    $title = 'Detail Trainer - EggGym Admin';
    $pageHeading = 'Detail Trainer';
    $name = $user?->name ?? 'Trainer';
    $initials = collect(preg_split('/\s+/', trim($name)))->filter()->take(2)->map(fn ($part) => mb_strtoupper(mb_substr($part, 0, 1)))->join('');
    $displayPhoto = $trainer->display_photo_path ? asset('storage/' . ltrim($trainer->display_photo_path, '/')) : null;
    $avatar = $user?->avatar_url;
    $avatarSrc = $avatar
        ? (\Illuminate\Support\Str::startsWith($avatar, ['http://', 'https://']) ? $avatar : asset('storage/' . ltrim($avatar, '/')))
        : null;
    $heroPhoto = $displayPhoto ?? $avatarSrc;
    $isActive = ($user?->status ?? 'inactive') === 'active';
    $money = $trainer->price_per_session !== null ? 'Rp ' . number_format((float) $trainer->price_per_session, 0, ',', '.') : 'Belum tersedia';
@endphp

@section('content')
    <style>
        .td-page { display: flex; flex-direction: column; gap: 18px; }
        .td-actions { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
        .td-actions__crumb { color: var(--muted); font-size: 12px; }
        .td-actions__buttons { display: flex; gap: 9px; }
        .td-hero {
            position: relative; min-height: 310px; overflow: hidden; border: 1px solid var(--border);
            border-radius: 14px; background: linear-gradient(120deg, #242424, #111); box-shadow: var(--shadow-card);
        }
        .td-hero__media { position: absolute; inset: 0; }
        .td-hero__media img { width: 100%; height: 100%; object-fit: cover; object-position: center 24%; }
        .td-hero__initial { width: 100%; height: 100%; display: flex; align-items: center; justify-content: flex-end; padding-right: 12%; color: rgba(250,204,21,.11); font-size: 150px; font-weight: 900; }
        .td-hero__overlay { position: absolute; inset: 0; background: linear-gradient(90deg, rgba(10,10,10,.96) 0%, rgba(10,10,10,.82) 43%, rgba(10,10,10,.12) 100%); }
        .td-hero__content { position: relative; z-index: 1; width: min(610px, 100%); min-height: 310px; padding: 34px; display: flex; flex-direction: column; justify-content: center; }
        .td-eyebrow { color: var(--accent); font-size: 10px; font-weight: 800; letter-spacing: 1.8px; text-transform: uppercase; }
        .td-name { margin-top: 10px; color: #fff; font-size: clamp(30px, 4vw, 48px); font-weight: 900; line-height: 1.05; }
        .td-contact { margin-top: 13px; display: flex; gap: 8px 18px; flex-wrap: wrap; color: #c9c3b7; font-size: 12px; }
        .td-tags { margin-top: 18px; display: flex; flex-wrap: wrap; gap: 8px; }
        .td-tag { padding: 6px 11px; border-radius: 999px; border: 1px solid #454545; background: rgba(24,24,24,.82); color: #ddd7ca; font-size: 10px; font-weight: 700; }
        .td-tag--tier { border-color: rgba(250,204,21,.4); color: var(--accent); }
        .td-tag--active { border-color: rgba(34,197,94,.35); color: #22c55e; }
        .td-tag--inactive { border-color: rgba(239,68,68,.35); color: #ef4444; }
        .td-stats { display: grid; grid-template-columns: repeat(5, minmax(0,1fr)); gap: 12px; }
        .td-stat { min-height: 112px; padding: 17px; border: 1px solid var(--border); border-radius: 12px; background: var(--panel); }
        .td-stat__label { color: var(--muted); font-size: 9px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
        .td-stat__value { margin-top: 13px; color: #fff; font-size: 24px; font-weight: 900; }
        .td-stat__value.is-accent { color: var(--accent); }
        .td-grid { display: grid; grid-template-columns: minmax(0,1.35fr) minmax(300px,.65fr); gap: 18px; align-items: start; }
        .td-stack { display: flex; flex-direction: column; gap: 18px; }
        .td-section { border: 1px solid var(--border); border-radius: 13px; background: var(--panel); padding: 22px; }
        .td-section__head { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; }
        .td-section__rail { width: 3px; height: 25px; background: var(--accent); }
        .td-section__title { color: #fff; font-size: 15px; font-weight: 900; text-transform: uppercase; letter-spacing: .6px; }
        .td-info-grid { display: grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap: 12px; }
        .td-info { padding: 14px; border-radius: 9px; background: var(--bg); border: 1px solid var(--border); }
        .td-info.is-wide { grid-column: 1 / -1; }
        .td-info__label { color: var(--muted); font-size: 9px; font-weight: 700; letter-spacing: .8px; text-transform: uppercase; }
        .td-info__value { margin-top: 7px; color: #ded8cd; font-size: 12px; line-height: 1.6; overflow-wrap: anywhere; white-space: pre-line; }
        .td-public-photo { width: 100%; aspect-ratio: 4/5; border-radius: 11px; overflow: hidden; border: 1px solid var(--border); background: var(--bg); }
        .td-public-photo img { width: 100%; height: 100%; object-fit: cover; }
        .td-photo-empty { width: 100%; height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 9px; color: var(--muted); text-align: center; padding: 24px; }
        .td-empty { color: var(--muted); font-size: 12px; line-height: 1.5; }
        .td-revenue-summary { display: grid; grid-template-columns: 1.4fr 1fr 1fr; gap: 10px; margin-bottom: 16px; }
        .td-revenue-metric { padding: 15px; border: 1px solid var(--border); border-radius: 10px; background: var(--bg); }
        .td-revenue-metric__label { color: var(--muted); font-size: 9px; font-weight: 800; letter-spacing: .8px; text-transform: uppercase; }
        .td-revenue-metric__value { margin-top: 8px; color: #fff; font-size: 21px; font-weight: 900; }
        .td-revenue-metric__value.is-accent { color: var(--accent); }
        .td-revenue-table { width: 100%; border-collapse: collapse; font-size: 12px; }
        .td-revenue-table th { padding: 10px 8px; color: var(--muted); font-size: 9px; letter-spacing: .8px; text-align: left; text-transform: uppercase; border-bottom: 1px solid var(--border); }
        .td-revenue-table td { padding: 12px 8px; color: #ded8cd; border-bottom: 1px solid var(--border); }
        .td-revenue-table tbody tr:last-child td { border-bottom: 0; }
        .td-revenue-table td:nth-child(n+2), .td-revenue-table th:nth-child(n+2) { text-align: right; }
        .td-revenue-table__amount { color: var(--accent) !important; font-weight: 800; }
        @media (max-width: 1050px) { .td-stats { grid-template-columns: repeat(3,1fr); } .td-grid { grid-template-columns: 1fr; } .td-public-photo { max-width: 380px; } }
        @media (max-width: 680px) { .td-hero__content { padding: 24px; } .td-hero__overlay { background: rgba(10,10,10,.83); } .td-stats { grid-template-columns: 1fr 1fr; } .td-info-grid { grid-template-columns: 1fr; } .td-info.is-wide { grid-column: auto; } .td-revenue-summary { grid-template-columns: 1fr; } .td-revenue-table { min-width: 520px; } .td-revenue-scroll { overflow-x: auto; } }
    </style>

    <div class="td-page">
        <div class="td-actions">
            <div class="td-actions__crumb">Personal Trainer / {{ $name }}</div>
            <div class="td-actions__buttons">
                <a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Kembali</a>
                <a href="{{ route('admin.trainer-profiles.edit', $trainer) }}" class="btn btn-primary">Edit Profil</a>
            </div>
        </div>

        <section class="td-hero">
            <div class="td-hero__media">
                @if ($heroPhoto)
                    <img src="{{ $heroPhoto }}" alt="Foto {{ $name }}">
                @else
                    <div class="td-hero__initial">{{ $initials ?: '?' }}</div>
                @endif
            </div>
            <div class="td-hero__overlay"></div>
            <div class="td-hero__content">
                <div class="td-eyebrow">Trainer Profile</div>
                <div class="td-name">{{ $name }}</div>
                <div class="td-contact">
                    <span>{{ $user?->email ?: 'Email belum tersedia' }}</span>
                    <span>{{ $user?->phone ?: 'Telepon belum tersedia' }}</span>
                </div>
                <div class="td-tags">
                    <span class="td-tag td-tag--tier">{{ $trainer->tier_label ?? 'Belum ada tier' }}</span>
                    <span class="td-tag {{ $isActive ? 'td-tag--active' : 'td-tag--inactive' }}">{{ $isActive ? 'Akun Aktif' : 'Akun Nonaktif' }}</span>
                    @forelse ($specialties as $specialty)
                        <span class="td-tag">{{ $specialty }}</span>
                    @empty
                        <span class="td-tag">Belum ada spesialisasi</span>
                    @endforelse
                </div>
            </div>
        </section>

        <section class="td-stats">
            <div class="td-stat">
                <div class="td-stat__label">Rating</div>
                <div class="td-stat__value is-accent">
                    @if ($trainer->reviews_count > 0)
                        {{ number_format((float) $trainer->rating_average, 1) }} / 5
                    @else
                        Belum ada rating
                    @endif
                </div>
                <div class="td-empty">{{ (int) $trainer->reviews_count }} ulasan</div>
            </div>
            <div class="td-stat"><div class="td-stat__label">Klien Aktif</div><div class="td-stat__value">{{ $activeClients }}</div></div>
            <div class="td-stat"><div class="td-stat__label">Kapasitas Klien</div><div class="td-stat__value">{{ (int) ($trainer->max_clients ?? 0) }}</div></div>
            <div class="td-stat"><div class="td-stat__label">Pengalaman</div><div class="td-stat__value">{{ (int) ($trainer->experience_years ?? 0) }} th</div></div>
            <div class="td-stat"><div class="td-stat__label">Status Akun</div><div class="td-stat__value" style="font-size:17px;color:{{ $isActive ? '#22c55e' : '#ef4444' }};">{{ $isActive ? 'Aktif' : 'Nonaktif' }}</div></div>
        </section>

        <div class="td-grid">
            <div class="td-stack">
                <section class="td-section">
                    <div class="td-section__head"><span class="td-section__rail"></span><span class="td-section__title">Informasi Profesional</span></div>
                    <div class="td-info-grid">
                        <div class="td-info"><div class="td-info__label">Spesialisasi</div><div class="td-info__value">{{ $specialties ? implode(', ', $specialties) : 'Belum ada spesialisasi.' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Tahun Pengalaman</div><div class="td-info__value">{{ $trainer->experience_years !== null ? $trainer->experience_years . ' tahun' : 'Belum tersedia.' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Bio</div><div class="td-info__value">{{ filled($trainer->bio) ? $trainer->bio : 'Belum ada bio trainer.' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Sertifikasi</div><div class="td-info__value">{{ filled($trainer->certifications) ? $trainer->certifications : 'Belum ada data sertifikasi.' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Catatan Availability</div><div class="td-info__value">{{ filled($trainer->availability_note) ? $trainer->availability_note : 'Belum ada catatan availability.' }}</div></div>
                    </div>
                </section>

                <section class="td-section">
                    <div class="td-section__head"><span class="td-section__rail"></span><span class="td-section__title">Pendapatan Bulanan PT</span></div>
                    <div class="td-revenue-summary">
                        <div class="td-revenue-metric">
                            <div class="td-revenue-metric__label">Pendapatan Bulan Ini</div>
                            <div class="td-revenue-metric__value is-accent">{{ $revenueSummary['current']['revenue_label'] }}</div>
                        </div>
                        <div class="td-revenue-metric">
                            <div class="td-revenue-metric__label">Booking Valid</div>
                            <div class="td-revenue-metric__value">{{ $revenueSummary['current']['valid_bookings'] }}</div>
                        </div>
                        <div class="td-revenue-metric">
                            <div class="td-revenue-metric__label">Sesi Terjual</div>
                            <div class="td-revenue-metric__value">{{ $revenueSummary['current']['sold_sessions'] }}</div>
                        </div>
                    </div>
                    @unless($revenueSummary['has_revenue'])
                        <div class="td-empty" style="margin-bottom:10px;">Belum ada pendapatan valid dari booking PT.</div>
                    @endunless
                    <div class="td-revenue-scroll">
                        <table class="td-revenue-table">
                            <thead><tr><th>Bulan</th><th>Pendapatan</th><th>Booking</th><th>Sesi</th></tr></thead>
                            <tbody>
                                @foreach($revenueSummary['months'] as $month)
                                    <tr>
                                        <td>{{ $month['label'] }}</td>
                                        <td class="td-revenue-table__amount">{{ $month['revenue_label'] }}</td>
                                        <td>{{ $month['valid_bookings'] }}</td>
                                        <td>{{ $month['sold_sessions'] }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                </section>

                <section class="td-section">
                    <div class="td-section__head"><span class="td-section__rail"></span><span class="td-section__title">Informasi Pembayaran</span></div>
                    <div class="td-info-grid">
                        <div class="td-info"><div class="td-info__label">Nama Bank</div><div class="td-info__value">{{ $trainer->bank_name ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Nomor Rekening</div><div class="td-info__value">{{ $trainer->bank_account_number ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Atas Nama Bank</div><div class="td-info__value">{{ $trainer->bank_account_name ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Nomor DANA</div><div class="td-info__value">{{ $trainer->dana_number ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Atas Nama DANA</div><div class="td-info__value">{{ $trainer->dana_account_name ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Metode Lainnya</div><div class="td-info__value">{{ $trainer->other_payment_method ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Nomor / ID Lainnya</div><div class="td-info__value">{{ $trainer->other_payment_number ?: '-' }}</div></div>
                        <div class="td-info"><div class="td-info__label">Atas Nama Lainnya</div><div class="td-info__value">{{ $trainer->other_payment_account_name ?: '-' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Harga per Sesi</div><div class="td-info__value" style="color:var(--accent);font-size:18px;font-weight:900;">{{ $money }}</div></div>
                    </div>
                </section>

            </div>

            <aside class="td-stack">
                <section class="td-section">
                    <div class="td-section__head"><span class="td-section__rail"></span><span class="td-section__title">Foto Tampilan Trainer</span></div>
                    <div class="td-public-photo">
                        @if ($displayPhoto)
                            <img src="{{ $displayPhoto }}" alt="Foto tampilan {{ $name }}">
                        @else
                            <div class="td-photo-empty"><span style="font-size:34px;">&#128247;</span><span>Belum ada foto tampilan trainer.</span></div>
                        @endif
                    </div>
                </section>

                <section class="td-section">
                    <div class="td-section__head"><span class="td-section__rail"></span><span class="td-section__title">Identitas Akun</span></div>
                    <div class="td-info-grid">
                        <div class="td-info is-wide"><div class="td-info__label">Email</div><div class="td-info__value">{{ $user?->email ?: '-' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Nomor Telepon</div><div class="td-info__value">{{ $user?->phone ?: '-' }}</div></div>
                        <div class="td-info is-wide"><div class="td-info__label">Bergabung</div><div class="td-info__value">{{ $trainer->created_at?->locale('id')->translatedFormat('d F Y') ?? '-' }}</div></div>
                    </div>
                </section>
            </aside>
        </div>
    </div>
@endsection
