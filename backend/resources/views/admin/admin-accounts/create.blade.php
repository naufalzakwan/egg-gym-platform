@extends('admin.layouts.app')

@php $title='Tambah Admin - EggGym Admin';$pageHeading='Tambah Admin';$pageSubheading='Buat akun terpisah untuk petugas Web Admin.'; @endphp

@section('content')
    <style>.aa-form{width:min(100%,720px);margin:0 auto;background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:22px}.aa-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.aa-full{grid-column:1/-1}.aa-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:20px}@media(max-width:640px){.aa-grid{grid-template-columns:1fr}.aa-full{grid-column:auto}.aa-actions .btn{flex:1}}</style>
    <form method="POST" action="{{ route('admin.admin-accounts.store') }}" class="aa-form">@csrf
        <div class="aa-grid">
            <div class="field aa-full"><label for="name">Nama Petugas</label><input id="name" name="name" value="{{ old('name') }}" required>@error('name')<div class="error">{{ $message }}</div>@enderror</div>
            <div class="field aa-full"><label for="email">Email</label><input id="email" type="email" name="email" value="{{ old('email') }}" autocomplete="off" required>@error('email')<div class="error">{{ $message }}</div>@enderror</div>
            <div class="field"><label for="password">Password</label><input id="password" type="password" name="password" autocomplete="new-password" required>@error('password')<div class="error">{{ $message }}</div>@enderror</div>
            <div class="field"><label for="password_confirmation">Konfirmasi Password</label><input id="password_confirmation" type="password" name="password_confirmation" autocomplete="new-password" required></div>
            <div class="field aa-full"><label for="status">Status Akun</label><select id="status" name="status"><option value="active" {{ old('status','active')==='active'?'selected':'' }}>Aktif</option><option value="inactive" {{ old('status')==='inactive'?'selected':'' }}>Nonaktif</option></select>@error('status')<div class="error">{{ $message }}</div>@enderror</div>
        </div><div class="aa-actions"><a href="{{ route('admin.admin-accounts.index') }}" class="btn btn-secondary">Kembali</a><button type="submit" class="btn btn-primary">Simpan Admin</button></div>
    </form>
@endsection
