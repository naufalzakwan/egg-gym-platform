@extends('admin.layouts.app')

@php
    $title = 'Broadcast Notifikasi - EggGym Admin';
    $pageHeading = 'Broadcast Notifikasi';
    $pageSubheading = 'Kirim notifikasi ke semua member sekaligus.';
@endphp

@section('content')
    <form method="POST" action="{{ route('admin.notifications.broadcast.send') }}" class="panel">
        @csrf

        <div class="form-grid">
            <div class="field">
                <label for="title">Judul Notifikasi</label>
                <input id="title" type="text" name="title" value="{{ old('title') }}" required placeholder="Contoh: Promo Spesial Juni">
                @error('title')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="type">Tipe Notifikasi</label>
                <select id="type" name="type" required>
                    @php $selectedType = old('type'); @endphp
                    <option value="promo" {{ $selectedType === 'promo' ? 'selected' : '' }}>Promo</option>
                    <option value="schedule" {{ $selectedType === 'schedule' ? 'selected' : '' }}>Schedule</option>
                    <option value="membership" {{ $selectedType === 'membership' ? 'selected' : '' }}>Membership</option>
                    <option value="general" {{ $selectedType === 'general' ? 'selected' : '' }}>General</option>
                </select>
                @error('type')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field field-full">
                <label for="message">Pesan Notifikasi</label>
                <textarea id="message" name="message" required placeholder="Tulis pesan yang akan dikirim ke semua member...">{{ old('message') }}</textarea>
                @error('message')<div class="error">{{ $message }}</div>@enderror
            </div>
        </div>

        <div class="actions" style="margin-top: 22px;">
            <button type="submit" class="btn btn-primary">Kirim ke Semua Member</button>
            <a href="{{ route('admin.notifications.index') }}" class="btn btn-secondary">Kembali</a>
        </div>
    </form>
@endsection
