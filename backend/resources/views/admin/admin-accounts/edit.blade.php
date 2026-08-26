@extends('admin.layouts.app')

@php $title='Edit Admin - EggGym Admin';$pageHeading='Edit Admin';$pageSubheading='Perbarui identitas petugas tanpa menampilkan password.'; @endphp

@section('content')
    <style>.aa-form{width:min(100%,720px);margin:0 auto;background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:22px}.aa-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:20px}@media(max-width:640px){.aa-actions .btn{flex:1}}</style>
    <form method="POST" action="{{ route('admin.admin-accounts.update', $adminAccount) }}" class="aa-form">@csrf @method('PUT')
        <div class="field"><label for="name">Nama Petugas</label><input id="name" name="name" value="{{ old('name',$adminAccount->name) }}" required>@error('name')<div class="error">{{ $message }}</div>@enderror</div>
        <div class="field" style="margin-top:16px"><label for="email">Email</label><input id="email" type="email" name="email" value="{{ old('email',$adminAccount->email) }}" required>@error('email')<div class="error">{{ $message }}</div>@enderror</div>
        <p class="help">Password tidak ditampilkan dan tidak diubah dari halaman ini.</p>
        <div class="aa-actions"><a href="{{ route('admin.admin-accounts.index') }}" class="btn btn-secondary">Kembali</a><button type="submit" class="btn btn-primary">Simpan Perubahan</button></div>
    </form>
@endsection
