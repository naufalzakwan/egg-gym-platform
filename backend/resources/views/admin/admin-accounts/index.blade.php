@extends('admin.layouts.app')

@php
    $title = 'Manajemen Admin - EggGym Admin';
    $pageHeading = 'Manajemen Admin';
    $pageSubheading = 'Kelola akun petugas Web Admin secara terpisah.';
@endphp

@section('content')
    <style>
        .aa-page { width: min(100%, 1100px); margin: 0 auto; }
        .aa-head { display:flex;align-items:flex-end;justify-content:space-between;gap:16px;margin-bottom:20px;flex-wrap:wrap; }
        .aa-head h1 { margin:0;font-size:28px; }.aa-head p{margin:7px 0 0;color:var(--muted);font-size:12px}
        .aa-panel{background:var(--panel);border:1px solid var(--border);border-radius:12px;overflow:hidden}
        .aa-row{display:grid;grid-template-columns:minmax(180px,1.5fr) minmax(210px,1.6fr) 110px 130px 150px;gap:14px;align-items:center;padding:14px 18px;border-bottom:1px solid var(--border)}
        .aa-row:last-child{border-bottom:0}.aa-row--head{color:var(--muted);font-size:10px;font-weight:800;text-transform:uppercase;letter-spacing:1px}
        .aa-name{font-weight:800}.aa-email{font-size:12px;color:var(--muted);overflow-wrap:anywhere}.aa-badge{display:inline-flex;width:max-content;padding:4px 9px;border-radius:999px;font-size:10px;font-weight:800;text-transform:uppercase}
        .aa-badge--active{color:#22c55e;background:rgba(34,197,94,.12)}.aa-badge--inactive{color:#ef4444;background:rgba(239,68,68,.12)}.aa-badge--owner{color:var(--accent);background:var(--accent-tint)}
        .aa-badge--current{color:#60a5fa;background:rgba(59,130,246,.13);margin-left:5px}.aa-self-note{display:inline-flex;align-items:center;color:var(--muted);font-size:10px;cursor:help}
        .aa-actions{display:flex;gap:7px;justify-content:flex-end}.aa-actions .btn{padding:7px 9px;font-size:10px}.aa-empty{padding:38px;text-align:center;color:var(--muted)}
        @media(max-width:800px){.aa-row{grid-template-columns:1fr}.aa-row--head{display:none}.aa-actions{justify-content:flex-start}}
    </style>
    <div class="aa-page">
        <div class="aa-head"><div><h1>Manajemen Admin</h1><p>Setiap petugas menggunakan akun sendiri. Tidak tersedia fitur pindah akun.</p></div><a href="{{ route('admin.admin-accounts.create') }}" class="btn btn-primary">+ Tambah Admin</a></div>
        <div class="aa-panel">
            <div class="aa-row aa-row--head"><div>Petugas</div><div>Email</div><div>Wewenang</div><div>Status</div><div></div></div>
            @forelse($admins as $admin)
                @php($isCurrentAdmin = $admin->is(auth()->user()))
                <div class="aa-row" data-admin-id="{{ $admin->id }}" {{ $isCurrentAdmin ? 'data-current-admin' : '' }}>
                    <div><div class="aa-name">{{ $admin->name }}</div><div class="aa-email">ID Admin #{{ $admin->id }}</div></div>
                    <div class="aa-email">{{ $admin->email }}</div>
                    <div><span class="aa-badge {{ $admin->is_admin_owner ? 'aa-badge--owner' : '' }}">{{ $admin->is_admin_owner ? 'Admin Utama' : 'Admin' }}</span>@if($isCurrentAdmin)<span class="aa-badge aa-badge--current">Akun Anda</span>@endif</div>
                    <div><span class="aa-badge aa-badge--{{ $admin->status === 'active' ? 'active' : 'inactive' }}">{{ $admin->status === 'active' ? 'Aktif' : 'Nonaktif' }}</span></div>
                    <div class="aa-actions"><a href="{{ route('admin.admin-accounts.edit', $admin) }}" class="btn btn-secondary">Edit</a>@if($isCurrentAdmin)<span class="aa-self-note" title="Akun yang sedang digunakan tidak dapat dinonaktifkan." aria-label="Akun yang sedang digunakan tidak dapat dinonaktifkan.">Tidak dapat dinonaktifkan</span>@else<form method="POST" action="{{ route('admin.admin-accounts.toggle-status', $admin) }}" onsubmit="return confirm('{{ $admin->status === 'active' ? 'Nonaktifkan' : 'Aktifkan' }} akun Admin ini?')">@csrf @method('PATCH')<button class="btn {{ $admin->status === 'active' ? 'btn-danger' : 'btn-secondary' }}" type="submit">{{ $admin->status === 'active' ? 'Nonaktifkan' : 'Aktifkan' }}</button></form>@endif</div>
                </div>
            @empty
                <div class="aa-empty">Belum ada akun Admin.</div>
            @endforelse
            @include('admin.partials.pagination', ['paginator' => $admins, 'itemLabel' => 'admin'])
        </div>
    </div>
@endsection
