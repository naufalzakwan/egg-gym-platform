@extends('admin.layouts.app')

@php
    $title = 'Notifications Admin EggGym';
    $pageHeading = 'Manajemen Notifikasi';
    $pageSubheading = 'Kirim notifikasi ke member dan pantau history notifikasi yang sudah terkirim.';
@endphp

@section('content')
    <div class="panel">
        <form method="GET" class="actions" style="justify-content: space-between; margin-bottom: 20px;">
            <div class="actions">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari judul, pesan, nama member" style="min-width: 320px;">
                <select name="type">
                    <option value="">Semua tipe</option>
                    @foreach ($types as $t)
                        <option value="{{ $t }}" {{ $type === $t ? 'selected' : '' }}>{{ $t }}</option>
                    @endforeach
                </select>
                <button type="submit" class="btn btn-secondary">Filter</button>
            </div>
            <div class="actions">
                <a href="{{ route('admin.notifications.create') }}" class="btn btn-primary">Kirim Notifikasi</a>
                <a href="{{ route('admin.notifications.broadcast') }}" class="btn btn-secondary">Broadcast</a>
            </div>
        </form>

        <table>
            <thead>
                <tr>
                    <th>Waktu</th>
                    <th>Member</th>
                    <th>Judul</th>
                    <th>Pesan</th>
                    <th>Tipe</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($notifications as $notification)
                    <tr>
                        <td>
                            <strong>{{ $notification->sent_at?->locale('id')->translatedFormat('d F Y H:i') ?? $notification->created_at?->locale('id')->translatedFormat('d F Y H:i') }}</strong>
                        </td>
                        <td>
                            <strong>{{ $notification->user?->name ?? '-' }}</strong>
                            <div class="help">{{ $notification->user?->email ?? '-' }}</div>
                        </td>
                        <td><strong>{{ $notification->title }}</strong></td>
                        <td>
                            <span class="help">{{ Str::limit($notification->message, 80) }}</span>
                        </td>
                        <td>
                            <span class="badge" style="background: rgba(244, 201, 93, 0.16); color: #f4c95d;">
                                {{ $notification->type }}
                            </span>
                        </td>
                        <td>
                            <span class="badge {{ $notification->is_read ? 'badge-active' : 'badge-inactive' }}">
                                {{ $notification->is_read ? 'Dibaca' : 'Belum dibaca' }}
                            </span>
                        </td>
                        <td>
                            <form method="POST" action="{{ route('admin.notifications.destroy', $notification) }}" onsubmit="return confirm('Hapus notifikasi ini?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="btn btn-danger">Hapus</button>
                            </form>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="7">Belum ada notifikasi yang terkirim.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        @include('admin.partials.pagination', ['paginator' => $notifications])
    </div>
@endsection
