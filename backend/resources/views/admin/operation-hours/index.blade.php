@extends('admin.layouts.app')

@php
    $title = 'Operation Hours Admin EggGym';
    $pageHeading = 'Master Data Operation Hours';
    $pageSubheading = 'Kelola jam buka tutup gym yang dipakai guest, member, dan admin.';
@endphp

@section('content')
    <div class="panel">
        <table>
            <thead>
                <tr>
                    <th>Hari</th>
                    <th>Urutan</th>
                    <th>Jam Buka</th>
                    <th>Jam Tutup</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($hours as $hour)
                    <tr>
                        <td><strong>{{ $hour->day_name }}</strong></td>
                        <td>{{ $hour->day_order }}</td>
                        <td>{{ $hour->open_time ? substr((string) $hour->open_time, 0, 5) : '-' }}</td>
                        <td>{{ $hour->close_time ? substr((string) $hour->close_time, 0, 5) : '-' }}</td>
                        <td>
                            <span class="badge {{ $hour->is_closed ? 'badge-inactive' : 'badge-active' }}">
                                {{ $hour->is_closed ? 'Tutup' : 'Buka' }}
                            </span>
                        </td>
                        <td>
                            <a href="{{ route('admin.operation-hours.edit', $hour) }}" class="btn btn-secondary">Edit</a>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
@endsection
