@extends('admin.layouts.app')

@php
    $title = $pageTitle . ' - EggGym Admin';
    $pageHeading = $pageTitle;
    $pageSubheading = 'Form jam operasional harian gym.';
@endphp

@section('content')
    <form method="POST" action="{{ $action }}" class="panel">
        @csrf
        @method('PUT')

        <div class="form-grid">
            <div class="field">
                <label for="day_name">Day Name</label>
                <input id="day_name" type="text" name="day_name" value="{{ old('day_name', $hour->day_name) }}" required>
                @error('day_name')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="day_order">Day Order</label>
                <input id="day_order" type="number" min="1" max="7" name="day_order" value="{{ old('day_order', $hour->day_order) }}" required>
                @error('day_order')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="open_time">Open Time</label>
                <input id="open_time" type="time" name="open_time" value="{{ old('open_time', $hour->open_time ? substr((string) $hour->open_time, 0, 5) : '') }}">
                @error('open_time')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="close_time">Close Time</label>
                <input id="close_time" type="time" name="close_time" value="{{ old('close_time', $hour->close_time ? substr((string) $hour->close_time, 0, 5) : '') }}">
                @error('close_time')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field field-full">
                <label>
                    <input type="hidden" name="is_closed" value="0">
                    <input type="checkbox" name="is_closed" value="1" {{ old('is_closed', $hour->is_closed) ? 'checked' : '' }}>
                    Gym tutup pada hari ini
                </label>
            </div>
        </div>

        <div class="actions" style="margin-top: 22px;">
            <button type="submit" class="btn btn-primary">{{ $submitLabel }}</button>
            <a href="{{ route('admin.operation-hours.index') }}" class="btn btn-secondary">Kembali</a>
        </div>
    </form>
@endsection
