@extends('admin.layouts.app')

@php
    use App\Http\Controllers\Web\Admin\AuditTrailController;
    $title = 'Audit Trail - EggGym Admin';
    $pageHeading = 'Audit Trail';
    $pageSubheading = 'Catatan aktivitas penting untuk keamanan dan akuntabilitas EGGGYM.';
    $activeQuery = ['search' => $search, 'actor' => $actor, 'category' => $category, 'date' => $dateRange];
    $roleClass = fn($role) => match(strtoupper($role)) {
        'ADMIN' => 'at-role-admin', 'TRAINER' => 'at-role-trainer',
        'MEMBER' => 'at-role-member', default => 'at-role-system',
    };
@endphp

@section('content')
<style>
    .at-hero{position:relative;overflow:hidden;padding:10px 0 22px;margin-bottom:4px}.at-hero__wm{position:absolute;right:-20px;top:-36px;font-size:150px;font-weight:900;letter-spacing:-5px;color:rgba(250,204,21,.04);pointer-events:none;line-height:1}.at-hero__inner{position:relative;z-index:1;max-width:650px}.at-hero__supra{font-size:10px;font-weight:800;letter-spacing:3px;text-transform:uppercase;color:var(--accent);margin-bottom:8px}.at-hero h1{font-size:36px;font-weight:800;margin:0 0 8px}.at-hero p{margin:0;color:var(--muted);font-size:13px;line-height:1.6}
    .at-filter{display:grid;gap:10px;padding:12px;margin-bottom:20px;background:var(--panel);border:1px solid var(--border);border-radius:10px}.at-categories{display:flex;gap:6px;overflow-x:auto;padding-bottom:2px}.at-pill{flex:0 0 auto;padding:7px 12px;border:1px solid var(--border);border-radius:999px;background:var(--bg);color:var(--muted);font-size:10px;font-weight:800;text-transform:uppercase;letter-spacing:.6px;text-decoration:none}.at-pill.active{background:var(--accent);border-color:var(--accent);color:var(--on-accent)}.at-controls{display:flex;gap:8px;align-items:flex-end;flex-wrap:wrap}.at-controls form{display:flex;gap:8px;align-items:flex-end;flex:1;flex-wrap:wrap}.at-control{display:grid;gap:4px;min-width:145px}.at-control>span{color:var(--text-muted);font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:.7px}.at-select{height:36px;width:100%;padding:0 30px 0 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:11px}.at-search{display:flex;align-items:center;gap:7px;min-width:220px;flex:1;height:36px;padding:0 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px}.at-search input{height:100%;padding:0;border:0;background:transparent}.at-export{height:36px;display:inline-flex;align-items:center;padding:0 12px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--muted);font-size:10px;font-weight:800;text-decoration:none;text-transform:uppercase}
    .at-timeline{position:relative;padding-left:8px}.at-timeline::before{content:'';position:absolute;left:15px;top:6px;bottom:6px;width:1px;background:var(--border)}.at-entry{display:flex;gap:16px;align-items:flex-start;padding-bottom:16px;position:relative}.at-dot{width:14px;height:14px;border-radius:50%;flex:0 0 auto;margin-top:18px;background:var(--accent);box-shadow:0 0 7px rgba(250,204,21,.35);z-index:2}.at-card{flex:1;min-width:0;padding:14px 17px;background:var(--panel);border:1px solid var(--border);border-radius:10px;box-shadow:var(--shadow-card)}.at-head{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap}.at-actor{display:flex;align-items:center;gap:9px}.at-avatar{width:30px;height:30px;display:grid;place-items:center;border-radius:50%;background:var(--panel-soft);color:var(--accent);font-size:11px;font-weight:800}.at-name{font-size:13px;font-weight:700}.at-role,.at-status{display:inline-flex;padding:3px 8px;border-radius:4px;font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:1px}.at-role-admin{color:var(--accent);background:rgba(250,204,21,.13)}.at-role-member{color:#22c55e;background:rgba(34,197,94,.12)}.at-role-trainer{color:#60a5fa;background:rgba(59,130,246,.13)}.at-role-system{color:#f87171;background:rgba(239,68,68,.12)}.at-time{color:var(--muted);font-size:10px;font-family:"JetBrains Mono",monospace}.at-body{display:grid;grid-template-columns:2fr 1.5fr .8fr;gap:14px;margin-top:10px;padding-top:10px;border-top:1px solid var(--border)}.at-label{margin-bottom:4px;color:var(--text-muted);font-size:9px;font-weight:800;text-transform:uppercase;letter-spacing:1px}.at-value{color:var(--text);font-size:12px;line-height:1.5}.at-status-success{color:#22c55e;background:rgba(34,197,94,.12)}.at-status-warning{color:#f59e0b;background:rgba(245,158,11,.12)}.at-status-danger{color:#ef4444;background:rgba(239,68,68,.12)}.at-source{margin-top:8px;color:var(--muted);font-size:10px}.at-changes{margin-top:10px;padding-top:9px;border-top:1px solid var(--border)}.at-changes summary{width:max-content;color:var(--accent);font-size:10px;font-weight:800;cursor:pointer;text-transform:uppercase;letter-spacing:.6px}.at-change-list{display:grid;gap:7px;margin-top:9px}.at-change-row{display:grid;grid-template-columns:minmax(150px,.8fr) 1fr 22px 1fr;gap:9px;align-items:center;padding:9px 10px;border:1px solid var(--border);border-radius:6px;background:var(--bg)}.at-change-field{font-size:11px;font-weight:700;color:var(--text-secondary)}.at-change-value{font-size:11px;color:var(--text);overflow-wrap:anywhere}.at-change-arrow{color:var(--accent);text-align:center}.at-change-row.is-single{grid-template-columns:minmax(150px,.8fr) 1fr}.at-empty{padding:40px;text-align:center;color:var(--muted);background:var(--panel);border:1px solid var(--border);border-radius:10px}.at-foot{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:12px 4px 28px;flex-wrap:wrap}.at-foot__info{font-size:11px;color:var(--muted)}.at-pager{display:flex;gap:6px}.at-pager a,.at-pager span{height:30px;min-width:30px;display:grid;place-items:center;padding:0 8px;border:1px solid var(--border);border-radius:5px;background:var(--panel);color:var(--muted);font-size:11px;text-decoration:none}.at-pager .active{background:var(--accent);border-color:var(--accent);color:var(--on-accent)}.at-pager .disabled{opacity:.45}.at-pager .ellipsis{border:0;background:transparent}
    @media(max-width:800px){.at-body,.at-change-grid{grid-template-columns:1fr}.at-controls form{width:100%}.at-select,.at-search{width:100%;min-width:0}.at-export{width:100%;justify-content:center}}
</style>

<div class="at-hero"><div class="at-hero__wm">LOGS</div><div class="at-hero__inner"><div class="at-hero__supra">Keamanan & Akuntabilitas EGGGYM</div><h1>ARSIP AKTIVITAS</h1><p>Catatan aktivitas penting yang tidak dapat diubah untuk mendukung keamanan dan akuntabilitas sistem EGGGYM.</p></div></div>

<div class="at-filter">
    <div class="at-categories">
        @foreach($categoryLabels as $key => $label)
            <a href="{{ route('admin.audit-trail.index', array_filter(array_merge($activeQuery, ['category' => $key]), fn($value) => $value !== 'all' && $value !== '')) }}" class="at-pill {{ $category === $key ? 'active' : '' }}">{{ $label }}</a>
        @endforeach
    </div>
    <div class="at-controls">
        <form method="GET" action="{{ route('admin.audit-trail.index') }}">
            <input type="hidden" name="category" value="{{ $category }}">
            <label class="at-control"><span>Rentang Tanggal</span><select name="date" class="at-select" onchange="this.form.submit()"><option value="all">Semua Tanggal</option><option value="today" {{ $dateRange==='today'?'selected':'' }}>Hari Ini</option><option value="week" {{ $dateRange==='week'?'selected':'' }}>Minggu Ini</option><option value="month" {{ $dateRange==='month'?'selected':'' }}>Bulan Ini</option></select></label>
            <label class="at-control"><span>Pelaku</span><select name="actor" class="at-select" onchange="this.form.submit()"><option value="all">Semua Pelaku</option><option value="admin" {{ $actor==='admin'?'selected':'' }}>Admin</option><option value="member" {{ $actor==='member'?'selected':'' }}>Member</option><option value="trainer" {{ $actor==='trainer'?'selected':'' }}>Personal Trainer</option><option value="system" {{ $actor==='system'?'selected':'' }}>Sistem</option></select></label>
            <label class="at-control" style="flex:1"><span>Search Log</span><span class="at-search"><span>&#128269;</span><input type="search" name="search" value="{{ $search }}" placeholder="Cari log, pelaku, target..."></span></label>
        </form>
        <a href="{{ route('admin.audit-trail.export', array_filter($activeQuery, fn($value) => $value !== 'all' && $value !== '')) }}" class="at-export">Export Excel</a>
    </div>
</div>

<div class="at-timeline">
    @forelse($logs as $log)
        @php
            $role = AuditTrailController::resolveRole($log);
            $status = AuditTrailController::resolveStatus($log);
            $changes = AuditTrailController::safeChanges($log);
            $actorName = $log->user?->name ?? 'Sistem';
        @endphp
        <div class="at-entry"><div class="at-dot"></div><article class="at-card">
            <div class="at-head"><div class="at-actor"><div class="at-avatar">{{ strtoupper(mb_substr($actorName,0,1)) }}</div><span class="at-name">{{ $actorName }}</span><span class="at-role {{ $roleClass($role) }}">{{ $role }}</span></div><time class="at-time">{{ $log->created_at?->locale('id')->translatedFormat('d F Y H:i:s') }}</time></div>
            <div class="at-body"><div><div class="at-label">Aktivitas</div><div class="at-value">{{ $log->description ?: $log->action }}</div></div><div><div class="at-label">Objek Terdampak</div><div class="at-value">{{ AuditTrailController::resolveTarget($log) }}</div></div><div><div class="at-label">Hasil</div><span class="at-status at-status-{{ $status['type'] }}">{{ $status['label'] }}</span></div></div>
            <div class="at-source">Sumber: {{ AuditTrailController::resolveSource($log) }}</div>
            @if($changes !== [])
                <details class="at-changes"><summary>{{ $changes['title'] }}</summary><div class="at-change-list">@foreach($changes['rows'] as $change)<div class="at-change-row {{ $changes['mode'] === 'update' ? '' : 'is-single' }}"><span class="at-change-field">{{ $change['label'] }}</span>@if($changes['mode'] === 'update')<span class="at-change-value">{{ $change['old'] }}</span><span class="at-change-arrow">→</span><span class="at-change-value">{{ $change['new'] }}</span>@elseif($changes['mode'] === 'create')<span class="at-change-value">{{ $change['new'] }}</span>@else<span class="at-change-value">{{ $change['old'] }}</span>@endif</div>@endforeach</div></details>
            @endif
        </article></div>
    @empty
        <div class="at-empty">{{ $search !== '' ? 'Tidak ada data yang cocok.' : 'Belum ada aktivitas pada filter ini.' }}</div>
    @endforelse
</div>

<div class="at-foot"><div class="at-foot__info">@if($logs->total()>0)Menampilkan {{ $logs->firstItem() }}&ndash;{{ $logs->lastItem() }} dari {{ number_format($logs->total(),0,',','.') }} aktivitas @else Menampilkan 0 dari 0 aktivitas @endif</div>
    @if($logs->lastPage()>1)
        @php($pages=collect(range(1,$logs->lastPage()))->filter(fn($page)=>$page===1||$page===$logs->lastPage()||abs($page-$logs->currentPage())<=1))
        <nav class="at-pager">@if($logs->onFirstPage())<span class="disabled">Prev</span>@else<a href="{{ $logs->previousPageUrl() }}">Prev</a>@endif @php($previous=0) @foreach($pages as $page) @if($page-$previous>1)<span class="ellipsis">&hellip;</span>@endif @if($page===$logs->currentPage())<span class="active">{{ $page }}</span>@else<a href="{{ $logs->url($page) }}">{{ $page }}</a>@endif @php($previous=$page) @endforeach @if($logs->hasMorePages())<a href="{{ $logs->nextPageUrl() }}">Next</a>@else<span class="disabled">Next</span>@endif</nav>
    @endif
</div>
@endsection
