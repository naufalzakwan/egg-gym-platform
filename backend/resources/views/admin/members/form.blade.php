@extends('admin.layouts.app')

@php
    $title = $pageTitle . ' - EggGym Admin';
    $pageHeading = $pageTitle;
    $pageSubheading = 'Kelola data akun member yang terhubung ke aplikasi mobile.';
    $isEdit = $method !== 'POST';
@endphp

@section('content')
    <style>
        .mbr-form-section-title {
            font-size: 12px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase;
            color: var(--muted); border-bottom: 1px solid var(--border); padding-bottom: 8px;
            margin: 4px 0 4px; grid-column: 1 / -1;
        }
        .mbr-form-section-title:first-child { margin-top: 0; }
    </style>

    <form method="POST" action="{{ $action }}" class="panel">
        @csrf
        @if ($method !== 'POST')
            @method($method)
        @endif

        @if (session('error'))
            <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">
                {{ session('error') }}
            </div>
        @endif

        <div class="form-grid">
            <div class="mbr-form-section-title">Informasi Personal</div>

            <div class="field">
                <label for="name">Nama Lengkap</label>
                <input id="name" type="text" name="name" value="{{ old('name', $member->user?->name) }}" required
                    placeholder="Nama lengkap member">
                @error('name')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="email">Email</label>
                <input id="email" type="email" name="email" value="{{ old('email', $member->user?->email) }}" required
                    placeholder="nama@email.com">
                @error('email')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="phone">Nomor Telepon</label>
                <input id="phone" type="text" name="phone" value="{{ old('phone', $member->user?->phone) }}"
                    placeholder="08XX-XXXX-XXXX">
                @error('phone')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="password">Password {{ $isEdit ? '(kosongkan jika tidak diubah)' : '(opsional)' }}</label>
                <input id="password" type="password" name="password" placeholder="Minimal 8 karakter">
                <div class="help">{{ $isEdit ? 'Isi hanya bila ingin mengganti password member.' : 'Bila dikosongkan, password default: member12345.' }}</div>
                @error('password')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="gender">Jenis Kelamin</label>
                <select id="gender" name="gender">
                    <option value="">- Pilih -</option>
                    <option value="male" {{ old('gender', $member->gender) === 'male' ? 'selected' : '' }}>Laki-laki</option>
                    <option value="female" {{ old('gender', $member->gender) === 'female' ? 'selected' : '' }}>Perempuan</option>
                </select>
                @error('gender')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="birth_date">Tanggal Lahir</label>
                <input id="birth_date" type="date" name="birth_date"
                    value="{{ old('birth_date', optional($member->birth_date)->format('Y-m-d')) }}">
                @error('birth_date')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="status">Status Akun</label>
                <select id="status" name="status">
                    <option value="active" {{ old('status', $member->user?->status ?? 'active') === 'active' ? 'selected' : '' }}>Aktif</option>
                    <option value="inactive" {{ old('status', $member->user?->status) === 'inactive' ? 'selected' : '' }}>Nonaktif</option>
                </select>
                @error('status')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="mbr-form-section-title">Data Fisik</div>

            <div class="field">
                <label for="height_cm">Tinggi Badan (cm)</label>
                <input id="height_cm" type="number" step="0.1" name="height_cm"
                    value="{{ old('height_cm', $member->height_cm) }}" placeholder="Contoh: 170">
                @error('height_cm')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="weight_kg">Berat Badan (kg)</label>
                <input id="weight_kg" type="number" step="0.1" name="weight_kg"
                    value="{{ old('weight_kg', $member->weight_kg) }}" placeholder="Contoh: 65">
                @error('weight_kg')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field field-full">
                <label for="fitness_goal">Target / Goal Latihan</label>
                <input id="fitness_goal" type="text" name="fitness_goal"
                    value="{{ old('fitness_goal', $member->fitness_goal) }}" placeholder="Contoh: Turun berat badan, bulking, dll">
                @error('fitness_goal')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="mbr-form-section-title">Keanggotaan (Opsional)</div>

            <div class="field field-full">
                <div class="help">Isi bagian ini untuk langsung membuatkan membership aktif bagi member. Biarkan kosong jika tidak perlu.</div>
            </div>

            <div class="field">
                <label for="membership_plan_id">Paket Membership</label>
                <select id="membership_plan_id" name="membership_plan_id">
                    <option value="">- Tanpa Paket -</option>
                    @foreach ($plans as $plan)
                        <option value="{{ $plan->id }}" {{ old('membership_plan_id') == $plan->id ? 'selected' : '' }}>{{ $plan->name }}</option>
                    @endforeach
                </select>
                @error('membership_plan_id')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="duration_months">Durasi</label>
                <select id="duration_months" name="duration_months">
                    <option value="1" {{ old('duration_months') == 1 ? 'selected' : '' }}>1 Bulan</option>
                    <option value="3" {{ old('duration_months') == 3 ? 'selected' : '' }}>3 Bulan</option>
                    <option value="6" {{ old('duration_months') == 6 ? 'selected' : '' }}>6 Bulan</option>
                    <option value="12" {{ old('duration_months') == 12 ? 'selected' : '' }}>12 Bulan</option>
                </select>
                @error('duration_months')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="start_date">Tanggal Mulai</label>
                <input id="start_date" type="date" name="start_date"
                    value="{{ old('start_date', now()->format('Y-m-d')) }}">
                @error('start_date')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="payment_status">Status Pembayaran</label>
                <select id="payment_status" name="payment_status">
                    <option value="paid" {{ old('payment_status', 'paid') === 'paid' ? 'selected' : '' }}>Lunas</option>
                    <option value="pending" {{ old('payment_status') === 'pending' ? 'selected' : '' }}>Menunggu</option>
                    <option value="unpaid" {{ old('payment_status') === 'unpaid' ? 'selected' : '' }}>Belum Bayar</option>
                </select>
                @error('payment_status')<div class="error">{{ $message }}</div>@enderror
            </div>
        </div>

        <div class="actions" style="margin-top: 22px;">
            <button type="submit" class="btn btn-primary">{{ $submitLabel }}</button>
            <a href="{{ route('admin.members.index') }}" class="btn btn-secondary">Batal</a>
        </div>
    </form>
@endsection
