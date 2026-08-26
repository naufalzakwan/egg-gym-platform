@extends('admin.layouts.app')

@php
    $title = $pageTitle . ' - EggGym Admin';
    $pageHeading = $pageTitle;
    $pageSubheading = 'Kirim notifikasi langsung ke member tertentu.';
@endphp

@section('content')
    <form method="POST" action="{{ $action }}" class="panel">
        @csrf

        <div class="form-grid">
            <div class="field field-full">
                <label for="user_id">Member Tujuan</label>
                <select id="user_id" name="user_id" required>
                    <option value="">Pilih member</option>
                    @foreach ($members as $member)
                        <option value="{{ $member->id }}" {{ old('user_id') == $member->id ? 'selected' : '' }}>
                            {{ $member->name }} ({{ $member->email }})
                        </option>
                    @endforeach
                </select>
                @error('user_id')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="title">Judul Notifikasi</label>
                <input id="title" type="text" name="title" value="{{ old('title') }}" required placeholder="Contoh: Pengingat Membership">
                @error('title')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="type">Tipe Notifikasi</label>
                <select id="type" name="type" required>
                    @php $selectedType = old('type'); @endphp
                    <option value="membership" {{ $selectedType === 'membership' ? 'selected' : '' }}>Membership</option>
                    <option value="booking" {{ $selectedType === 'booking' ? 'selected' : '' }}>Booking</option>
                    <option value="payment" {{ $selectedType === 'payment' ? 'selected' : '' }}>Payment</option>
                    <option value="promo" {{ $selectedType === 'promo' ? 'selected' : '' }}>Promo</option>
                    <option value="schedule" {{ $selectedType === 'schedule' ? 'selected' : '' }}>Schedule</option>
                    <option value="reminder" {{ $selectedType === 'reminder' ? 'selected' : '' }}>Reminder</option>
                    <option value="general" {{ $selectedType === 'general' ? 'selected' : '' }}>General</option>
                </select>
                @error('type')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field field-full">
                <label for="message">Pesan Notifikasi</label>
                <textarea id="message" name="message" required placeholder="Tulis pesan notifikasi yang akan dikirim ke member...">{{ old('message') }}</textarea>
                @error('message')<div class="error">{{ $message }}</div>@enderror
            </div>
        </div>

        <div class="actions" style="margin-top: 22px;">
            <button type="submit" class="btn btn-primary">{{ $submitLabel }}</button>
            <a href="{{ route('admin.notifications.index') }}" class="btn btn-secondary">Kembali</a>
        </div>
    </form>
@endsection
