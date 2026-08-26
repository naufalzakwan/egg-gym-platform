@extends('admin.layouts.app')

@php
    $title = 'Notifikasi Admin - EGGGYM';
    $pageHeading = 'Notifikasi';
    $pageSubheading = 'Action penting dan monitoring operasional untuk Admin.';
@endphp

@section('content')
    <style>
        .ni-head{display:flex;justify-content:space-between;align-items:center;gap:14px;margin-bottom:18px}.ni-list{display:grid;gap:10px}.ni-item{display:grid;grid-template-columns:44px 1fr auto;gap:13px;align-items:start;padding:16px;border:1px solid var(--border);border-radius:11px;background:var(--panel)}.ni-item.is-unread{background:rgba(250,204,21,.06);border-color:rgba(250,204,21,.32)}.ni-item.is-high{border-left:3px solid var(--danger)}.ni-icon{width:40px;height:40px;border-radius:50%;display:grid;place-items:center;background:var(--panel-soft);font-size:18px}.ni-title{font-weight:800;font-size:14px}.ni-message{margin-top:4px;color:var(--text-secondary);font-size:12px;line-height:1.45}.ni-meta{margin-top:7px;color:var(--muted);font-size:10px}.ni-new{color:var(--danger);font-size:9px;font-weight:800;text-transform:uppercase}.ni-empty{padding:50px;text-align:center;color:var(--muted);background:var(--panel);border:1px solid var(--border);border-radius:12px}@media(max-width:720px){.ni-item{grid-template-columns:40px 1fr}.ni-item form{grid-column:2}.ni-head{align-items:flex-start;flex-direction:column}}
    </style>
    <div class="ni-head"><div><h1 style="margin:0;">Pusat Notifikasi</h1><p style="color:var(--muted);margin:5px 0 0;">{{ $unreadCount }} belum dibaca</p></div>@if($unreadCount>0)<form method="POST" action="{{ route('admin.notifications.read-all') }}">@csrf<button class="btn btn-secondary">Tandai semua dibaca</button></form>@endif</div>
    @if($notifications->isEmpty())<div class="ni-empty">Belum ada notifikasi</div>@else<div class="ni-list">@foreach($notifications as $notification)<article class="ni-item {{ !$notification->is_read?'is-unread':'' }} {{ $notification->priority==='high'?'is-high':'' }}"><div class="ni-icon">{{ match($notification->type){'payment'=>'💳','booking'=>'📅','program'=>'📋','schedule','reminder'=>'⏰','membership'=>'⭐',default=>'🔔'} }}</div><div><div class="ni-title">{{ $notification->title }} @if(!$notification->is_read)<span class="ni-new">Baru</span>@endif</div><div class="ni-message">{{ $notification->message }}</div><div class="ni-meta">{{ ($notification->sent_at??$notification->created_at)?->locale('id')->diffForHumans() }} · {{ strtoupper($notification->priority) }}</div></div><form method="POST" action="{{ route('admin.notifications.read',$notification->id) }}">@csrf<button class="btn btn-secondary">{{ $notification->is_read?'Buka':'Baca' }}</button></form></article>@endforeach</div>@include('admin.partials.pagination',['paginator'=>$notifications,'itemLabel'=>'notifikasi'])@endif
@endsection
