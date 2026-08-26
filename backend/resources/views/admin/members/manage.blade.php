@extends('admin.layouts.app')

@php
    $name = $member->user?->name ?? 'Member';
    $title = 'Kelola Member - EggGym Admin';
    $pageHeading = 'Kelola Member';
    $pageSubheading = 'Member / '.$name;
    $accountActive = $member->user?->status === 'active';
    $membershipActive = $activeMembership?->isCurrentlyActive() ?? false;
@endphp

@section('content')
    <style>
        .mm-head { display:flex; justify-content:space-between; align-items:flex-start; gap:16px; margin-bottom:18px; }
        .mm-head h1 { margin:0 0 5px; font-size:28px; }
        .mm-head p { margin:0; color:var(--muted); font-size:12px; }
        .mm-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:18px; align-items:start; }
        .mm-card { background:var(--panel); border:1px solid var(--border); border-radius:12px; padding:22px; box-shadow:var(--shadow-card); }
        .mm-card--wide { grid-column:1/-1; }
        .mm-card__title { color:var(--muted); font-size:11px; font-weight:800; letter-spacing:1.3px; text-transform:uppercase; }
        .mm-card__desc { margin-top:6px; color:var(--text-muted); font-size:11px; line-height:1.5; }
        .mm-summary { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:12px; margin-top:16px; }
        .mm-item { padding:12px 14px; border-radius:8px; background:var(--bg); border:1px solid var(--border); min-width:0; }
        .mm-item__label { color:var(--muted); font-size:9px; font-weight:700; letter-spacing:.8px; text-transform:uppercase; }
        .mm-item__value { margin-top:6px; color:var(--text); font-size:13px; font-weight:700; overflow-wrap:anywhere; }
        .mm-profile { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; margin-top:16px; }
        .mm-note { margin-top:16px; padding:12px 14px; border-left:3px solid var(--accent); background:var(--accent-tint); color:var(--text-secondary); font-size:11px; line-height:1.5; }
        .mm-form { margin-top:16px; }
        .mm-warning { margin-top:14px; padding:12px 14px; border:1px solid rgba(245,158,11,.4); border-radius:8px; background:rgba(245,158,11,.08); color:#FBBF24; font-size:11px; line-height:1.5; }
        .mm-confirm { display:flex; align-items:flex-start; gap:9px; margin-top:14px; color:var(--text-secondary); font-size:11px; }
        .mm-confirm input { width:17px; height:17px; margin-top:1px; accent-color:var(--accent); }
        .mm-actions { display:flex; gap:10px; flex-wrap:wrap; margin-top:16px; }
        @media(max-width:900px){ .mm-grid,.mm-summary,.mm-profile{grid-template-columns:1fr}.mm-card--wide{grid-column:auto}.mm-head{flex-direction:column} }
    </style>

    @if(session('success'))<div class="flash">{{ session('success') }}</div>@endif
    @if(session('error'))<div class="error" style="margin-bottom:16px;">{{ session('error') }}</div>@endif
    @if($errors->any())<div class="error" style="margin-bottom:16px;">{{ $errors->first() }}</div>@endif

    <div class="mm-head">
        <div><h1>Detail & Kelola Member</h1><p>Member / {{ $name }}</p></div>
        <a href="{{ route('admin.members.index') }}" class="btn btn-secondary">Kembali</a>
    </div>

    <div class="mm-grid">
        <section class="mm-card mm-card--wide">
            <div class="mm-card__title">Ringkasan Member</div>
            <div class="mm-summary">
                <div class="mm-item"><div class="mm-item__label">Nama Member</div><div class="mm-item__value">{{ $name }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Email</div><div class="mm-item__value">{{ $member->user?->email ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Nomor Telepon</div><div class="mm-item__value">{{ $member->user?->phone ?: '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Status Akun</div><div class="mm-item__value">{{ $accountActive ? 'Aktif' : 'Nonaktif' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Paket Aktif</div><div class="mm-item__value">{{ $activeMembership?->membershipPlan?->name ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Tanggal Mulai</div><div class="mm-item__value">{{ $activeMembership?->start_date?->locale('id')->translatedFormat('d F Y') ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Tanggal Berakhir</div><div class="mm-item__value">{{ $activeMembershipEnd?->locale('id')->translatedFormat('d F Y') ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Status Membership</div><div class="mm-item__value">{{ $membershipActive ? 'Aktif' : 'Nonaktif' }}</div></div>
            </div>
        </section>

        <section class="mm-card">
            <div class="mm-card__title">Profil Member</div>
            <div class="mm-card__desc">Informasi pribadi dan fisik ditampilkan sebagai data read-only.</div>
            <div class="mm-profile">
                <div class="mm-item"><div class="mm-item__label">Kode Member</div><div class="mm-item__value">{{ $member->member_code ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Jenis Kelamin</div><div class="mm-item__value">{{ $member->gender === 'male' ? 'Laki-laki' : ($member->gender === 'female' ? 'Perempuan' : '-') }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Tanggal Lahir</div><div class="mm-item__value">{{ $member->birth_date?->locale('id')->translatedFormat('d F Y') ?? '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Tinggi Badan</div><div class="mm-item__value">{{ $member->height_cm !== null ? number_format((float)$member->height_cm,1,',','.').' cm' : '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Berat Badan</div><div class="mm-item__value">{{ $member->weight_kg !== null ? number_format((float)$member->weight_kg,1,',','.').' kg' : '-' }}</div></div>
                <div class="mm-item"><div class="mm-item__label">Goal Latihan</div><div class="mm-item__value">{{ $member->fitness_goal ?: '-' }}</div></div>
            </div>
            <div class="mm-note">Data profil member dikelola oleh member melalui aplikasi mobile. Password lama tidak dapat dilihat; reset hanya tersedia melalui card khusus Admin.</div>
        </section>

        <section class="mm-card">
            <div class="mm-card__title">Kontrol Admin</div>
            <div class="mm-card__desc">Status akun mengatur akses login Member, bukan status Membership.</div>
            <form class="mm-form" method="POST" action="{{ route('admin.members.update',$member) }}">@csrf @method('PUT')
                <div class="field"><label for="status">Status Akun</label><select id="status" name="status" required><option value="active" {{ old('status',$member->user?->status)==='active'?'selected':'' }}>Aktif</option><option value="inactive" {{ old('status',$member->user?->status)==='inactive'?'selected':'' }}>Nonaktif</option></select>@error('status')<div class="error">{{ $message }}</div>@enderror</div>
                <div class="mm-actions"><button class="btn btn-primary">Simpan Status Akun</button></div>
            </form>
        </section>

        <section class="mm-card">
            <div class="mm-card__title">Reset Password Member</div>
            <div class="mm-card__desc">Gunakan fitur ini hanya jika member lupa password dan meminta bantuan Admin.</div>
            <div class="mm-warning">Password lama tidak dapat dilihat. Admin hanya dapat membuat password baru.</div>
            <form class="mm-form" method="POST" action="{{ route('admin.members.password.update',$member) }}">@csrf @method('PUT')
                <div class="field"><label for="password">Password Baru</label><input id="password" type="password" name="password" minlength="8" autocomplete="new-password" required>@error('password')<div class="error">{{ $message }}</div>@enderror</div>
                <div class="field" style="margin-top:12px;"><label for="password_confirmation">Konfirmasi Password Baru</label><input id="password_confirmation" type="password" name="password_confirmation" minlength="8" autocomplete="new-password" required></div>
                <label class="mm-confirm"><input id="password_reset_confirmation" type="checkbox" name="password_reset_confirmation" value="1" required><span>Saya memahami bahwa password member akan diganti.</span></label>
                <div class="mm-actions"><button id="passwordResetButton" class="btn btn-secondary" disabled>Reset Password</button></div>
            </form>
        </section>
    </div>
    <script>
        (() => {
            const confirmation = document.getElementById('password_reset_confirmation');
            const button = document.getElementById('passwordResetButton');
            confirmation?.addEventListener('change', () => { if (button) button.disabled = !confirmation.checked; });
        })();
    </script>
@endsection
