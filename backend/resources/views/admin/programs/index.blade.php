@extends('admin.layouts.app')

@php
    $title = 'Programs Admin EggGym';
    $pageHeading = 'Program Monitor';
    $pageSubheading = 'Pantau program training per member dan trainer dari dashboard admin.';
@endphp

@section('content')
    <div class="panel">
        <form method="GET" class="actions" style="justify-content: space-between; margin-bottom: 20px;">
            <div class="actions">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari title, goal, member, trainer" style="min-width: 320px;">
                <select name="status">
                    <option value="">Semua status</option>
                    <option value="draft" {{ $status === 'draft' ? 'selected' : '' }}>draft</option>
                    <option value="active" {{ $status === 'active' ? 'selected' : '' }}>active</option>
                    <option value="archived" {{ $status === 'archived' ? 'selected' : '' }}>archived</option>
                </select>
                <button type="submit" class="btn btn-secondary">Filter</button>
            </div>
        </form>

        <table>
            <thead>
                <tr>
                    <th>Program</th>
                    <th>Member</th>
                    <th>Trainer</th>
                    <th>Status</th>
                    <th>Sesi</th>
                    <th>Booking Terkait</th>
                    <th>Periode</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($programs as $program)
                    <tr>
                        <td>
                            <strong>{{ $program->title }}</strong>
                            <div class="help">{{ $program->goal ?? '-' }}</div>
                        </td>
                        <td>
                            <strong>{{ $program->memberProfile?->user?->name ?? '-' }}</strong>
                            <div class="help">{{ $program->memberProfile?->member_code ?? '-' }}</div>
                        </td>
                        <td>
                            <strong>{{ $program->trainerProfile?->user?->name ?? '-' }}</strong>
                            <div class="help">{{ collect($program->trainerProfile?->specialty_labels ?? [])->join(', ') ?: '-' }}</div>
                        </td>
                        <td>
                            @php
                                $statusClass = match ($program->status) {
                                    'active' => 'badge-active',
                                    'draft' => 'pending',
                                    default => 'badge-inactive',
                                };
                            @endphp
                            <span class="badge {{ $statusClass === 'pending' ? '' : $statusClass }}" style="{{ $statusClass === 'pending' ? 'background: rgba(244, 201, 93, 0.16); color: #f4c95d;' : '' }}">
                                {{ $program->status }}
                            </span>
                        </td>
                        <td>
                            <strong>{{ $program->sessions_count }}</strong>
                            <div class="help">{{ $program->sessions->sum(fn($session) => (int) ($session->duration_minutes ?? 0)) }} menit</div>
                        </td>
                        <td>
                            @if ($program->booking)
                                <strong>{{ $program->booking->session_title }}</strong>
                                <div class="help">{{ $program->booking->session_date?->locale('id')->translatedFormat('d F Y') }}</div>
                            @else
                                <span class="help">Tidak terkait booking</span>
                            @endif
                        </td>
                        <td>
                            <strong>{{ $program->started_at?->locale('id')->translatedFormat('d F Y') ?? '-' }}</strong>
                            <div class="help">s/d {{ $program->ended_at?->locale('id')->translatedFormat('d F Y') ?? '-' }}</div>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="7">Belum ada program yang cocok dengan filter saat ini.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        @include('admin.partials.pagination', ['paginator' => $programs])
    </div>
@endsection
