@extends('admin.layouts.app')

@php
    $title = 'Pengaturan - EggGym Admin';
    $pageHeading = 'Pengaturan';
    $pageSubheading = 'Pusat konfigurasi umum EGGGYM.';
    $isOwner = (bool) $admin?->is_admin_owner;
    $openDays = $hours->where('is_closed', false);
    $hoursSummary = $openDays->isEmpty()
        ? 'Belum ada jam operasional aktif'
        : $openDays->count().' hari buka · '.substr((string) $openDays->first()?->open_time, 0, 5).'–'.substr((string) $openDays->first()?->close_time, 0, 5);
@endphp

@section('content')
    <style>
        .st-intro { margin-bottom: 22px; }
        .st-intro h1 { margin: 0 0 6px; font-size: 29px; }
        .st-intro p { margin: 0; color: var(--muted); font-size: 13px; }
        .st-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; align-items: start; }
        .st-card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 22px; box-shadow: var(--shadow-card); }
        .st-card--wide { grid-column: 1 / -1; }
        .st-card__head { display: flex; align-items: flex-start; gap: 14px; }
        .st-card__icon { width: 42px; height: 42px; flex: 0 0 42px; display: grid; place-items: center; border-radius: 10px; background: var(--accent-tint); color: var(--accent); font-size: 19px; }
        .st-card__body { min-width: 0; flex: 1; }
        .st-card__title { font-size: 15px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; }
        .st-card__desc { margin-top: 5px; color: var(--muted); font-size: 12px; line-height: 1.5; }
        .st-card__summary { margin-top: 14px; padding: 12px 14px; border-radius: 8px; background: var(--bg); color: var(--text-secondary); font-size: 13px; line-height: 1.55; }
        .st-card__actions { margin-top: 16px; display: flex; gap: 10px; flex-wrap: wrap; }
        .st-details { margin-top: 18px; border-top: 1px solid var(--border); padding-top: 18px; }
        .st-details summary { cursor: pointer; color: var(--accent); font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: .7px; }
        .st-form { margin-top: 17px; }
        .st-form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
        .st-field { display: flex; flex-direction: column; gap: 7px; }
        .st-field--wide { grid-column: 1 / -1; }
        .st-field label { color: var(--muted); font-size: 10px; letter-spacing: 1px; text-transform: uppercase; }
        .st-field textarea { min-height: 82px; }
        .st-logo-preview { width: 92px; height: 92px; border-radius: 12px; border: 1px solid var(--border); background: var(--bg); display: grid; place-items: center; overflow: hidden; color: var(--accent); font-size: 28px; font-weight: 900; }
        .st-logo-preview img { width: 100%; height: 100%; object-fit: contain; }
        .st-brand-row { display: flex; align-items: center; gap: 16px; margin-bottom: 16px; }
        .st-methods { display: grid; gap: 9px; margin-top: 15px; }
        .st-method { display: grid; grid-template-columns: minmax(130px, 1.2fr) minmax(140px, 1.5fr) 90px 72px; gap: 10px; align-items: center; padding: 11px; border: 1px solid var(--border); border-radius: 8px; background: var(--bg); }
        .st-method code { color: var(--accent); font-size: 11px; }
        .st-method input[type="checkbox"] { width: 18px; height: 18px; justify-self: center; accent-color: var(--accent); }
        .st-hours { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-top: 14px; }
        .st-hour { display: flex; justify-content: space-between; gap: 12px; padding: 10px 12px; border-radius: 8px; background: var(--bg); border: 1px solid var(--border); font-size: 12px; }
        .st-hour span:last-child { color: var(--muted); }
        .st-admin-stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 9px; margin-top: 14px; }
        .st-admin-stat { padding: 12px; border-radius: 8px; background: var(--bg); border: 1px solid var(--border); }
        .st-admin-stat strong { display: block; color: var(--accent); font-size: 24px; }
        .st-admin-stat span { color: var(--muted); font-size: 9px; text-transform: uppercase; letter-spacing: .7px; }
        .st-readonly { margin-top: 14px; color: var(--muted); font-size: 11px; }
        @media (max-width: 900px) { .st-grid, .st-form-grid, .st-hours { grid-template-columns: 1fr; } .st-card--wide, .st-field--wide { grid-column: auto; } .st-method { grid-template-columns: 1fr; } .st-method input[type="checkbox"] { justify-self: start; } }
    </style>

    @if (session('success'))<div class="flash">{{ session('success') }}</div>@endif
    @if ($errors->any())
        <div class="error" style="margin-bottom:16px;">{{ $errors->first() }}</div>
    @endif

    <div class="st-intro">
        <h1>Pengaturan EGGGYM</h1>
        <p>Identitas, layanan publik, dan akses operasional dalam satu pusat konfigurasi.</p>
    </div>

    <div class="st-grid">
        <section class="st-card">
            <div class="st-card__head"><div class="st-card__icon">&#127970;</div><div class="st-card__body">
                <div class="st-card__title">Identitas & Lokasi Gym</div>
                <div class="st-card__desc">Informasi lokasi utama yang dibaca aplikasi dan Web Admin.</div>
            </div></div>
            <div class="st-card__summary"><strong>{{ $settings->gym_name }}</strong><br>{{ collect([$settings->address, $settings->city, $settings->province])->filter()->join(', ') ?: 'Lokasi belum dilengkapi' }}</div>
            @if($isOwner)
                <details class="st-details"><summary>Kelola Lokasi</summary>
                    <form class="st-form" method="POST" action="{{ route('admin.settings.identity.update') }}">@csrf @method('PUT')
                        <div class="st-form-grid">
                            <div class="st-field"><label>Nama Gym</label><input name="gym_name" value="{{ old('gym_name', $settings->gym_name) }}" required></div>
                            <div class="st-field"><label>Tagline</label><input name="tagline" value="{{ old('tagline', $settings->tagline) }}"></div>
                            <div class="st-field st-field--wide"><label>Alamat Lengkap</label><textarea name="address" required>{{ old('address', $settings->address) }}</textarea></div>
                            <div class="st-field"><label>Kota</label><input name="city" value="{{ old('city', $settings->city) }}" required></div>
                            <div class="st-field"><label>Provinsi</label><input name="province" value="{{ old('province', $settings->province) }}" required></div>
                            <div class="st-field"><label>Kode Pos</label><input name="postal_code" value="{{ old('postal_code', $settings->postal_code) }}"></div>
                            <div class="st-field"><label>Google Maps</label><input type="url" name="maps_url" value="{{ old('maps_url', $settings->maps_url) }}"></div>
                            <div class="st-field"><label>Latitude</label><input type="number" step="0.0000001" name="latitude" value="{{ old('latitude', $settings->latitude) }}"></div>
                            <div class="st-field"><label>Longitude</label><input type="number" step="0.0000001" name="longitude" value="{{ old('longitude', $settings->longitude) }}"></div>
                        </div><div class="st-card__actions"><button class="btn btn-primary">Simpan Lokasi</button></div>
                    </form>
                </details>
            @else<div class="st-readonly">Hanya Admin Utama dapat mengubah lokasi.</div>@endif
        </section>

        <section class="st-card">
            <div class="st-card__head"><div class="st-card__icon">&#9733;</div><div class="st-card__body">
                <div class="st-card__title">Branding EGGGYM</div><div class="st-card__desc">Logo dan identitas brand dengan fallback default.</div>
            </div></div>
            <div class="st-card__summary">{{ $settings->brand_name }} · {{ $settings->tagline ?: 'Tanpa tagline' }}</div>
            @if($isOwner)
                <details class="st-details"><summary>Kelola Branding</summary>
                    <form class="st-form" method="POST" action="{{ route('admin.settings.branding.update') }}" enctype="multipart/form-data">@csrf @method('PUT')
                        <div class="st-brand-row"><div class="st-logo-preview" data-logo-preview>
                            @if($settings->logo_path)<img src="{{ asset('storage/'.$settings->logo_path) }}?v={{ $settings->logo_version }}" alt="Logo {{ $settings->brand_name }}">@else E @endif
                        </div><div><strong>Logo Utama</strong><div class="st-card__desc">PNG, JPG, atau WebP. Maksimal 4 MB.</div></div></div>
                        <div class="st-form-grid">
                            <div class="st-field"><label>Nama Brand</label><input name="brand_name" value="{{ old('brand_name', $settings->brand_name) }}" required></div>
                            <div class="st-field"><label>Tagline</label><input name="tagline" value="{{ old('tagline', $settings->tagline) }}"></div>
                            <div class="st-field st-field--wide"><label>Ganti Logo</label><input type="file" name="logo" accept="image/png,image/jpeg,image/webp" data-logo-input></div>
                        </div><div class="st-card__actions"><button class="btn btn-primary">Simpan Branding</button></div>
                    </form>
                    @if($settings->logo_path)<form method="POST" action="{{ route('admin.settings.branding.logo.destroy') }}" style="margin-top:10px;">@csrf @method('DELETE')<button class="btn btn-secondary">Hapus / Kembali ke Default</button></form>@endif
                </details>
            @else<div class="st-readonly">Hanya Admin Utama dapat mengubah branding.</div>@endif
        </section>

        <section class="st-card st-card--wide">
            <div class="st-card__head"><div class="st-card__icon">&#128179;</div><div class="st-card__body">
                <div class="st-card__title">Metode Pembayaran Membership</div><div class="st-card__desc">{{ $paymentMethods->where('is_active', true)->count() }} dari {{ $paymentMethods->count() }} channel Pakasir aktif untuk checkout baru.</div>
            </div></div>
            @if($isOwner)
                <details class="st-details"><summary>Kelola Metode</summary>
                    <form class="st-form" method="POST" action="{{ route('admin.settings.payment-methods.update') }}">@csrf @method('PUT')
                        <div class="st-methods">
                            @foreach($paymentMethods as $index => $method)
                                <div class="st-method">
                                    <div><strong>{{ $method->display_name }}</strong><br><code>{{ $method->provider_code }}</code></div>
                                    <input type="hidden" name="methods[{{ $index }}][id]" value="{{ $method->id }}">
                                    <input name="methods[{{ $index }}][display_name]" value="{{ $method->display_name }}" aria-label="Label {{ $method->provider_code }}" required>
                                    <input type="number" name="methods[{{ $index }}][display_order]" value="{{ $method->display_order }}" min="0" max="10000" aria-label="Urutan {{ $method->provider_code }}" required>
                                    <input type="checkbox" name="methods[{{ $index }}][is_active]" value="1" {{ $method->is_active ? 'checked' : '' }} aria-label="Aktifkan {{ $method->provider_code }}">
                                </div>
                            @endforeach
                        </div><div class="st-card__actions"><button class="btn btn-primary">Simpan Metode</button></div>
                    </form>
                </details>
            @else<div class="st-readonly">Daftar channel hanya dapat diubah Admin Utama.</div>@endif
        </section>

        <section class="st-card">
            <div class="st-card__head"><div class="st-card__icon">&#128222;</div><div class="st-card__body">
                <div class="st-card__title">Kontak & Jam Operasional</div><div class="st-card__desc">Kontak publik dan jadwal buka gym existing.</div>
            </div></div>
            <div class="st-card__summary">{{ $settings->phone ?: 'Kontak belum dilengkapi' }}<br>{{ $hoursSummary }}</div>
            <div class="st-hours">@foreach($hours as $hour)<div class="st-hour"><strong>{{ $hour->day_name }}</strong><span>{{ $hour->is_closed ? 'Tutup' : substr((string) $hour->open_time, 0, 5).'–'.substr((string) $hour->close_time, 0, 5) }}</span></div>@endforeach</div>
            @if($isOwner)
                <details class="st-details"><summary>Kelola Kontak</summary>
                    <form class="st-form" method="POST" action="{{ route('admin.settings.contact.update') }}">@csrf @method('PUT')
                        <div class="st-form-grid">
                            <div class="st-field"><label>Nomor Telepon</label><input name="phone" value="{{ old('phone', $settings->phone) }}" required></div>
                            <div class="st-field"><label>WhatsApp</label><input name="whatsapp" value="{{ old('whatsapp', $settings->whatsapp) }}" required></div>
                            <div class="st-field"><label>Email Gym</label><input type="email" name="email" value="{{ old('email', $settings->email) }}" required></div>
                            <div class="st-field"><label>Instagram</label><input name="instagram" value="{{ old('instagram', $settings->instagram) }}"></div>
                        </div><div class="st-card__actions"><button class="btn btn-primary">Simpan Kontak</button><a class="btn btn-secondary" href="{{ route('admin.operation-hours.index') }}">Kelola Jam</a></div>
                    </form>
                </details>
            @else<div class="st-readonly">Hanya Admin Utama dapat mengubah kontak dan jam operasional.</div>@endif
        </section>

        @if($adminAccountMetrics !== null)
            <section class="st-card" data-admin-account-card>
                <div class="st-card__head"><div class="st-card__icon">&#128101;</div><div class="st-card__body">
                    <div class="st-card__title">Manajemen Akun Admin</div><div class="st-card__desc">Kelola akun petugas Admin, status akses, dan identitas yang tercatat pada Audit Trail.</div>
                </div></div>
                <div class="st-admin-stats"><div class="st-admin-stat"><strong>{{ $adminAccountMetrics['total'] }}</strong><span>Seluruh</span></div><div class="st-admin-stat"><strong>{{ $adminAccountMetrics['active'] }}</strong><span>Aktif</span></div><div class="st-admin-stat"><strong>{{ $adminAccountMetrics['inactive'] }}</strong><span>Nonaktif</span></div></div>
                <div class="st-card__actions"><a href="{{ route('admin.admin-accounts.index') }}" class="btn btn-primary">Kelola Akun</a></div>
            </section>
        @endif
    </div>

    <script>
        (() => {
            const input = document.querySelector('[data-logo-input]');
            const preview = document.querySelector('[data-logo-preview]');
            input?.addEventListener('change', () => {
                const file = input.files?.[0];
                if (!file || !preview) return;
                const image = document.createElement('img');
                image.alt = 'Preview logo baru';
                image.src = URL.createObjectURL(file);
                image.onload = () => URL.revokeObjectURL(image.src);
                preview.replaceChildren(image);
            });
        })();
    </script>
@endsection
