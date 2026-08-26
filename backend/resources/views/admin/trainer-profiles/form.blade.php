@extends('admin.layouts.app')

@php
    $isEdit = $method !== 'POST';
    $selectedTier = old('tier', $isEdit ? $trainer->tier_value : 'pro');
    $title = $pageTitle . ' - EggGym Admin';
    $pageHeading = $pageTitle;
    $hideTopbarTitle = !$isEdit;
    $pageSubheading = $isEdit
        ? 'Kelola tier, kapasitas klien, verifikasi, dan catatan internal Admin.'
        : 'Form pembuatan akun user dan profil trainer.';
@endphp

@section('content')
    @if($isEdit)
        @php
            $avatar = $user->avatar_url;
            $avatarSrc = $avatar
                ? (\Illuminate\Support\Str::startsWith($avatar, ['http://', 'https://']) ? $avatar : asset('storage/' . ltrim($avatar, '/')))
                : null;
            $initial = mb_strtoupper(mb_substr($user->name ?? 'T', 0, 1));
        @endphp
        <style>
            .ta-page { display:flex; flex-direction:column; gap:16px; }
            .ta-head { display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; }
            .ta-crumb { color:var(--muted); font-size:12px; }
            .ta-summary { display:flex; align-items:center; gap:16px; padding:18px 20px; }
            .ta-avatar { width:72px; height:72px; border-radius:14px; overflow:hidden; flex-shrink:0; background:var(--panel-soft); display:flex; align-items:center; justify-content:center; color:var(--accent); font-size:27px; font-weight:900; }
            .ta-avatar img { width:100%; height:100%; object-fit:cover; }
            .ta-summary__name { color:#fff; font-size:20px; font-weight:900; }
            .ta-summary__email { margin-top:4px; color:var(--muted); font-size:12px; }
            .ta-summary__meta { margin-top:9px; display:flex; gap:7px; flex-wrap:wrap; }
            .ta-chip { padding:5px 9px; border-radius:999px; border:1px solid var(--border); color:#d8d2c6; font-size:9px; font-weight:700; }
            .ta-chip.is-active { color:#22c55e; border-color:rgba(34,197,94,.35); }
            .ta-chip.is-inactive { color:#ef4444; border-color:rgba(239,68,68,.35); }
            .ta-form { max-width:900px; padding:22px; }
            .ta-form__head { margin-bottom:18px; }
            .ta-form__title { color:var(--accent); font-size:13px; font-weight:900; letter-spacing:1px; text-transform:uppercase; }
            .ta-form__help { margin-top:6px; color:var(--muted); font-size:11px; line-height:1.5; }
            .ta-grid { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
            .ta-wide { grid-column:1 / -1; }
            .ta-actions { display:flex; gap:10px; margin-top:20px; }
            @media(max-width:680px){ .ta-grid{grid-template-columns:1fr;} .ta-wide{grid-column:auto;} .ta-summary{align-items:flex-start;} }
        </style>

        <div class="ta-page">
            <div class="ta-head">
                <div class="ta-crumb">Personal Trainer / {{ $user->name }}</div>
                <a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Kembali</a>
            </div>

            <div class="panel ta-summary">
                <div class="ta-avatar">
                    @if($avatarSrc)<img src="{{ $avatarSrc }}" alt="Avatar {{ $user->name }}">@else{{ $initial }}@endif
                </div>
                <div>
                    <div class="ta-summary__name">{{ $user->name }}</div>
                    <div class="ta-summary__email">{{ $user->email }}</div>
                    <div class="ta-summary__meta">
                        @foreach(($specialtyDisplays ?? []) as $specialty)<span class="ta-chip">{{ $specialty }}</span>@endforeach
                        <span class="ta-chip {{ $user->status === 'active' ? 'is-active' : 'is-inactive' }}">Akun {{ $user->status === 'active' ? 'Aktif' : 'Nonaktif' }}</span>
                    </div>
                </div>
            </div>

            <form method="POST" action="{{ $action }}" class="panel ta-form">
                @csrf
                @method($method)
                <div class="ta-form__head">
                    <div class="ta-form__title">Kontrol Admin</div>
                    <div class="ta-form__help">Status akun active/inactive dikelola terpisah melalui tombol nonaktifkan coach pada daftar trainer. Data profesional dan pembayaran tetap dikelola PT melalui aplikasi mobile.</div>
                </div>
                <div class="ta-grid">
                    <div class="field">
                        <label for="tier">Tier</label>
                        <select id="tier" name="tier" required>
                            @foreach($tierOptions as $value => $label)
                                <option value="{{ $value }}" {{ $selectedTier === $value ? 'selected' : '' }}>{{ $label }}</option>
                            @endforeach
                        </select>
                        @error('tier')<div class="error">{{ $message }}</div>@enderror
                    </div>
                    <div class="field">
                        <label for="max_clients">Kapasitas Klien Maksimal</label>
                        <input id="max_clients" type="number" name="max_clients" min="1" max="500" value="{{ old('max_clients', $trainer->max_clients ?? 30) }}" required>
                        @error('max_clients')<div class="error">{{ $message }}</div>@enderror
                    </div>
                    <div class="field">
                        <label for="verification_status">Status Verifikasi PT</label>
                        <select id="verification_status" name="verification_status" required>
                            @foreach(['pending' => 'Pending', 'verified' => 'Verified', 'unverified' => 'Unverified'] as $value => $label)
                                <option value="{{ $value }}" {{ old('verification_status', $trainer->verification_status ?? 'pending') === $value ? 'selected' : '' }}>{{ $label }}</option>
                            @endforeach
                        </select>
                        @error('verification_status')<div class="error">{{ $message }}</div>@enderror
                    </div>
                    <div class="field ta-wide">
                        <label for="admin_notes">Catatan Admin Internal</label>
                        <textarea id="admin_notes" name="admin_notes" maxlength="5000" placeholder="Catatan ini hanya terlihat oleh Admin.">{{ old('admin_notes', $trainer->admin_notes) }}</textarea>
                        <div class="help">Tidak ditampilkan kepada trainer, member, atau guest.</div>
                        @error('admin_notes')<div class="error">{{ $message }}</div>@enderror
                    </div>
                </div>
                <div class="ta-actions">
                    <button type="submit" class="btn btn-primary">Simpan Perubahan</button>
                    <a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Batal</a>
                </div>
            </form>
        </div>
    @else
        @php $selectedSpecialties = old('specialties', []); @endphp
        <style>
            .tc-page { max-width:1180px; margin:0 auto; display:flex; flex-direction:column; gap:22px; }
            .tc-head { display:flex; align-items:flex-end; justify-content:space-between; gap:16px; flex-wrap:wrap; }
            .tc-head__title { color:#fff; font-size:24px; font-weight:900; letter-spacing:.5px; }
            .tc-crumb { margin-top:6px; color:var(--muted); font-size:12px; }
            .tc-head__actions { display:flex; gap:10px; }
            .tc-card { padding:22px; }
            .tc-card__head { margin-bottom:18px; }
            .tc-card__title { color:var(--accent); font-size:12px; font-weight:900; letter-spacing:1.2px; text-transform:uppercase; }
            .tc-card__sub { margin-top:5px; color:var(--muted); font-size:11px; line-height:1.5; }
            .tc-grid { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
            .tc-wide { grid-column:1 / -1; }
            .tc-password { position:relative; }
            .tc-password input { padding-right:76px; }
            .tc-password button { position:absolute; right:8px; top:50%; transform:translateY(-50%); border:0; background:transparent; color:var(--accent); font-size:11px; font-weight:800; cursor:pointer; }
            .tc-upload { display:grid; grid-template-columns:110px 1fr; gap:16px; align-items:center; }
            .tc-avatar-preview { width:110px; height:110px; border-radius:14px; overflow:hidden; border:1px solid var(--border); background:var(--bg); display:flex; align-items:center; justify-content:center; color:var(--muted); font-size:11px; text-align:center; }
            .tc-avatar-preview img { width:100%; height:100%; object-fit:cover; }
            .tc-dropzone { min-height:110px; border:1px dashed #555; border-radius:12px; background:var(--bg); padding:16px; display:flex; flex-direction:column; justify-content:center; gap:8px; cursor:pointer; transition:.15s ease; }
            .tc-dropzone:hover,.tc-dropzone.is-dragging { border-color:var(--accent); background:rgba(250,204,21,.05); }
            .tc-dropzone__title { color:#ddd7ca; font-size:12px; font-weight:800; }
            .tc-dropzone__help,.tc-file-name { color:var(--muted); font-size:10px; line-height:1.5; }
            .tc-file-actions { display:flex; gap:8px; flex-wrap:wrap; margin-top:5px; }
            .tc-file-actions button { border:1px solid var(--border); border-radius:7px; background:var(--panel-soft); color:#ddd7ca; padding:7px 10px; font-size:10px; font-weight:700; cursor:pointer; }
            .tc-file-actions button:hover { border-color:var(--accent); color:var(--accent); }
            .tc-file-actions .is-danger:hover { border-color:var(--danger); color:var(--danger); }
            .tc-upload-error { color:#ffc3c3; font-size:11px; display:none; }
            .tc-submit-error { display:none; padding:12px 14px; border:1px solid rgba(239,68,68,.35); border-radius:10px; background:rgba(239,68,68,.1); color:#ffc3c3; font-size:12px; line-height:1.5; }
            .tc-number { position:relative; }
            .tc-number input { padding-right:56px; }
            .tc-number__suffix { position:absolute; right:13px; top:50%; transform:translateY(-50%); color:var(--muted); font-size:11px; pointer-events:none; }
            .tc-rating { min-height:48px; display:flex; align-items:center; justify-content:space-between; gap:12px; padding:0 14px; border:1px solid var(--border); border-radius:12px; background:var(--panel-soft); }
            .tc-rating strong { color:var(--accent); font-size:16px; }
            .tc-rating span { color:var(--muted); font-size:10px; }
            .tc-specialty-grid { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:9px; }
            .tc-specialty { min-width:0; }
            .tc-specialty input { position:absolute; opacity:0; pointer-events:none; }
            .tc-specialty span { min-height:44px; display:flex; align-items:center; justify-content:center; padding:8px 10px; border:1px solid var(--border); border-radius:999px; background:var(--bg); color:#c9c3b7; font-size:11px; font-weight:700; text-align:center; cursor:pointer; transition:.15s ease; }
            .tc-specialty input:checked + span { border-color:var(--accent); background:rgba(250,204,21,.12); color:var(--accent); }
            .tc-specialty input:focus-visible + span { outline:2px solid var(--accent); outline-offset:2px; }
            .tc-specialty-count { margin-top:11px; color:var(--muted); font-size:11px; }
            .tc-specialty-count strong { color:var(--accent); }
            .tc-bio { min-height:110px; }
            .tc-certifications { min-height:90px; }
            .tc-availability { min-height:80px; }
            .tc-bottom { display:flex; justify-content:flex-end; gap:10px; padding-bottom:12px; }
            @media(max-width:900px){ .tc-specialty-grid{grid-template-columns:repeat(3,minmax(0,1fr));} }
            @media(max-width:680px){ .tc-grid{grid-template-columns:1fr;} .tc-wide{grid-column:auto;} .tc-specialty-grid{grid-template-columns:repeat(2,minmax(0,1fr));} .tc-head__actions,.tc-bottom{width:100%;} .tc-head__actions .btn,.tc-bottom .btn{flex:1;} }
            @media(max-width:420px){ .tc-specialty-grid{grid-template-columns:1fr;} .tc-upload{grid-template-columns:1fr;} }
        </style>

        <form method="POST" action="{{ $action }}" id="trainerCreateForm" class="tc-page" enctype="multipart/form-data">
            @csrf
            <input type="hidden" name="status" value="active">

            <div class="tc-head">
                <div><div class="tc-head__title">TAMBAH TRAINER</div><div class="tc-crumb">Personal Trainer / Tambah Trainer</div></div>
                <div class="tc-head__actions"><a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Kembali</a><button type="submit" class="btn btn-primary" data-submit-trainer>Simpan Trainer</button></div>
            </div>

            <div class="tc-submit-error" id="trainerSubmitError" role="alert"></div>

            <section class="panel tc-card">
                <div class="tc-card__head"><div class="tc-card__title">Informasi Akun</div><div class="tc-card__sub">Akun baru otomatis aktif. Status dapat diubah dari card trainer setelah tersimpan.</div></div>
                <div class="tc-grid">
                    <div class="field"><label for="name">Nama Trainer</label><input id="name" name="name" value="{{ old('name') }}" required>@error('name')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field"><label for="email">Email</label><input id="email" type="email" name="email" value="{{ old('email') }}" required>@error('email')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field"><label for="phone">Nomor Telepon</label><input id="phone" name="phone" value="{{ old('phone') }}" required>@error('phone')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field"><label for="password">Password</label><div class="tc-password"><input id="password" type="password" name="password" required><button type="button" id="passwordToggle" onclick="tcTogglePassword()">Tampilkan</button></div><div class="help">Minimal 8 karakter. Trainer dapat mengubahnya melalui aplikasi mobile.</div>@error('password')<div class="error">{{ $message }}</div>@enderror</div>
                </div>
            </section>

            <section class="panel tc-card">
                <div class="tc-card__head"><div class="tc-card__title">Spesialisasi</div><div class="tc-card__sub">Pilih minimal satu spesialisasi. Pilihan dikirim menggunakan payload existing <code>specialties[]</code>.</div></div>
                <div class="tc-specialty-grid">
                    @foreach($specialtyOptions as $option)
                        <label class="tc-specialty"><input type="checkbox" name="specialties[]" value="{{ $option }}" {{ in_array($option, $selectedSpecialties, true) ? 'checked' : '' }} onchange="tcUpdateSpecialtyCount()"><span>{{ $option }}</span></label>
                    @endforeach
                </div>
                <div class="tc-specialty-count"><strong id="specialtySelectedCount">{{ count($selectedSpecialties) }}</strong> spesialisasi dipilih</div>
                @error('specialties')<div class="error">{{ $message }}</div>@enderror
                @error('specialties.*')<div class="error">{{ $message }}</div>@enderror
            </section>

            <section class="panel tc-card">
                <div class="tc-card__head"><div class="tc-card__title">Profil Profesional</div><div class="tc-card__sub">Data awal trainer. Selanjutnya profil profesional dapat dikelola trainer melalui aplikasi mobile.</div></div>
                <div class="tc-grid">
                    <div class="field tc-wide">
                        <label for="avatar">Foto Profil Trainer</label>
                        <div class="tc-upload">
                            <div class="tc-avatar-preview" id="avatarPreview">Belum ada foto</div>
                            <div class="tc-dropzone" id="avatarDropzone" tabindex="0" role="button" aria-controls="avatar">
                                <input id="avatar" type="file" name="avatar" accept="image/jpeg,image/png,image/webp" hidden>
                                <div class="tc-dropzone__title">Klik atau tarik foto ke sini</div>
                                <div class="tc-dropzone__help">JPG, JPEG, PNG, atau WEBP. Maksimal 2 MB. Foto bersifat opsional.</div>
                                <div class="tc-file-name" id="avatarFileName">Belum ada file dipilih.</div>
                                <div class="tc-file-actions">
                                    <button type="button" id="avatarReplace">Pilih / Ganti Foto</button>
                                    <button type="button" class="is-danger" id="avatarRemove" hidden>Hapus Foto</button>
                                </div>
                            </div>
                        </div>
                        <div class="tc-upload-error" id="avatarError"></div>
                        @error('avatar')<div class="error">{{ $message }}</div>@enderror
                    </div>
                    <div class="field"><label for="experience_years">Experience Years</label><div class="tc-number"><input id="experience_years" type="number" name="experience_years" min="0" max="100" value="{{ old('experience_years', 0) }}"><span class="tc-number__suffix">tahun</span></div>@error('experience_years')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field tc-wide"><label for="bio">Bio</label><textarea id="bio" class="tc-bio" name="bio">{{ old('bio') }}</textarea>@error('bio')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field tc-wide"><label for="certifications">Certifications</label><textarea id="certifications" class="tc-certifications" name="certifications">{{ old('certifications') }}</textarea>@error('certifications')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field tc-wide"><label for="availability_note">Availability Note</label><textarea id="availability_note" class="tc-availability" name="availability_note">{{ old('availability_note') }}</textarea>@error('availability_note')<div class="error">{{ $message }}</div>@enderror</div>
                </div>
            </section>

            <section class="panel tc-card">
                <div class="tc-card__head"><div class="tc-card__title">Pengaturan Administratif</div><div class="tc-card__sub">Field internal yang dikelola Admin dan tidak mengubah informasi pembayaran atau jadwal trainer.</div></div>
                <div class="tc-grid">
                    <div class="field"><label for="tier">Tier</label><select id="tier" name="tier">@foreach($tierOptions as $value => $label)<option value="{{ $value }}" {{ $selectedTier === $value ? 'selected' : '' }}>{{ $label }}</option>@endforeach</select>@error('tier')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field"><label for="max_clients">Kapasitas Klien Maksimal</label><input id="max_clients" type="number" name="max_clients" min="1" max="500" value="{{ old('max_clients', 30) }}">@error('max_clients')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field"><label for="verification_status">Status Verifikasi</label><select id="verification_status" name="verification_status"><option value="pending" {{ old('verification_status', 'pending') === 'pending' ? 'selected' : '' }}>Pending</option><option value="verified" {{ old('verification_status') === 'verified' ? 'selected' : '' }}>Verified</option><option value="unverified" {{ old('verification_status') === 'unverified' ? 'selected' : '' }}>Unverified</option></select>@error('verification_status')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="field tc-wide"><label for="admin_notes">Catatan Admin Internal</label><textarea id="admin_notes" class="tc-availability" name="admin_notes" maxlength="5000" placeholder="Tidak tampil ke trainer, member, atau guest.">{{ old('admin_notes') }}</textarea>@error('admin_notes')<div class="error">{{ $message }}</div>@enderror</div>
                </div>
            </section>

            <div class="tc-bottom"><a href="{{ route('admin.trainer-profiles.index') }}" class="btn btn-secondary">Kembali</a><button type="submit" class="btn btn-primary" data-submit-trainer>Simpan Trainer</button></div>
        </form>

        <script>
            function tcTogglePassword() {
                const input = document.getElementById('password');
                const button = document.getElementById('passwordToggle');
                input.type = input.type === 'password' ? 'text' : 'password';
                button.textContent = input.type === 'password' ? 'Tampilkan' : 'Sembunyikan';
            }
            function tcUpdateSpecialtyCount() {
                document.getElementById('specialtySelectedCount').textContent =
                    document.querySelectorAll('input[name="specialties[]"]:checked').length;
            }
            const avatarInput = document.getElementById('avatar');
            const avatarDropzone = document.getElementById('avatarDropzone');
            const avatarError = document.getElementById('avatarError');
            let avatarObjectUrl = null;

            function tcOpenAvatarPicker() { avatarInput.click(); }
            function tcValidateAvatar(file) {
                const types = ['image/jpeg', 'image/png', 'image/webp'];
                if (!types.includes(file.type)) return 'Format foto harus JPG, JPEG, PNG, atau WEBP.';
                if (file.size > 2 * 1024 * 1024) return 'Ukuran foto maksimal 2 MB.';
                return '';
            }
            function tcSetAvatarFile(file) {
                const error = tcValidateAvatar(file);
                avatarError.textContent = error;
                avatarError.style.display = error ? 'block' : 'none';
                if (error) { avatarInput.value = ''; return false; }

                if (avatarObjectUrl) URL.revokeObjectURL(avatarObjectUrl);
                avatarObjectUrl = URL.createObjectURL(file);
                const image = document.createElement('img');
                image.src = avatarObjectUrl;
                image.alt = 'Preview foto profil trainer';
                document.getElementById('avatarPreview').replaceChildren(image);
                document.getElementById('avatarFileName').textContent = file.name;
                document.getElementById('avatarRemove').hidden = false;
                return true;
            }
            function tcRemoveAvatar() {
                if (avatarObjectUrl) URL.revokeObjectURL(avatarObjectUrl);
                avatarObjectUrl = null;
                avatarInput.value = '';
                document.getElementById('avatarPreview').textContent = 'Belum ada foto';
                document.getElementById('avatarFileName').textContent = 'Belum ada file dipilih.';
                document.getElementById('avatarRemove').hidden = true;
                avatarError.style.display = 'none';
            }

            avatarInput.addEventListener('change', () => { if (avatarInput.files[0]) tcSetAvatarFile(avatarInput.files[0]); });
            avatarDropzone.addEventListener('click', event => { if (!event.target.closest('button')) tcOpenAvatarPicker(); });
            avatarDropzone.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); tcOpenAvatarPicker(); } });
            document.getElementById('avatarReplace').addEventListener('click', tcOpenAvatarPicker);
            document.getElementById('avatarRemove').addEventListener('click', tcRemoveAvatar);
            ['dragenter', 'dragover'].forEach(type => avatarDropzone.addEventListener(type, event => { event.preventDefault(); avatarDropzone.classList.add('is-dragging'); }));
            ['dragleave', 'drop'].forEach(type => avatarDropzone.addEventListener(type, event => { event.preventDefault(); avatarDropzone.classList.remove('is-dragging'); }));
            avatarDropzone.addEventListener('drop', event => {
                const file = event.dataTransfer.files[0];
                if (!file || !tcSetAvatarFile(file)) return;
                const transfer = new DataTransfer();
                transfer.items.add(file);
                avatarInput.files = transfer.files;
            });

            document.getElementById('trainerCreateForm').addEventListener('submit', async event => {
                event.preventDefault();
                const form = event.currentTarget;
                const submitButtons = form.querySelectorAll('[data-submit-trainer]');
                const errorBox = document.getElementById('trainerSubmitError');
                if (avatarInput.files[0] && !tcSetAvatarFile(avatarInput.files[0])) return;

                submitButtons.forEach(button => { button.disabled = true; button.textContent = 'Menyimpan...'; });
                errorBox.style.display = 'none';
                try {
                    const response = await fetch(form.action, {
                        method: 'POST',
                        headers: { 'Accept': 'application/json', 'X-CSRF-TOKEN': form.querySelector('input[name="_token"]').value },
                        body: new FormData(form),
                    });
                    const payload = await response.json();
                    if (response.ok) {
                        window.location.assign(payload.redirect_url || `{{ route('admin.trainer-profiles.index') }}`);
                        return;
                    }
                    const avatarMessages = payload.errors?.avatar || [];
                    if (avatarMessages.length) {
                        avatarError.textContent = avatarMessages.join(' ');
                        avatarError.style.display = 'block';
                    }
                    const messages = Object.values(payload.errors || {}).flat();
                    errorBox.textContent = messages.length ? messages.join(' ') : (payload.message || 'Trainer gagal disimpan.');
                    errorBox.style.display = 'block';
                } catch (_) {
                    errorBox.textContent = 'Trainer gagal disimpan. Periksa koneksi lalu coba lagi.';
                    errorBox.style.display = 'block';
                } finally {
                    submitButtons.forEach(button => { button.disabled = false; button.textContent = 'Simpan Trainer'; });
                }
            });
            tcUpdateSpecialtyCount();
        </script>
    @endif
@endsection
