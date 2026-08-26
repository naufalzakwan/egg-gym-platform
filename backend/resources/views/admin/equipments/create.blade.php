@extends('admin.layouts.app')

@php
    $title = 'Tambah Alat - EggGym Admin';
    $pageHeading = 'Tambah Alat';
    $pageSubheading = 'Alat Gym / Tambah Alat';
    $keyBenefitsText = old('key_benefits_text', '');
    $usageFlowText = old('usage_flow_text', '');
    $safetyNotesText = old('safety_notes_text', '');
    $movementRows = old('movements', []);
@endphp

@section('content')
    @include('admin.equipments.partials.editor-styles')
    <style>
        .eq-create { width: min(100%, 1180px); margin: 0 auto; }
        .eq-create__header { display: flex; align-items: center; justify-content: space-between; gap: 18px; margin-bottom: 22px; }
        .eq-create__title { margin: 0; font-size: 24px; font-weight: 800; letter-spacing: 1.4px; text-transform: uppercase; }
        .eq-create__crumb { margin: 7px 0 0; color: var(--muted); font-size: 13px; }
        .eq-create__actions { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .eq-form { display: grid; gap: 22px; }
        .eq-card { padding: 22px; border: 1px solid var(--border); border-radius: 12px; background: var(--panel); box-shadow: var(--shadow-card); }
        .eq-card__head { margin-bottom: 18px; }
        .eq-card__title { margin: 0; font-size: 15px; font-weight: 800; letter-spacing: .7px; }
        .eq-card__sub { margin: 5px 0 0; color: var(--muted); font-size: 12px; line-height: 1.5; }
        .eq-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px 18px; }
        .eq-field { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
        .eq-field label { font-size: 12px; font-weight: 700; color: var(--text-secondary); }
        .eq-field input, .eq-field select, .eq-field textarea { border-radius: 8px; background: var(--panel-soft); }
        .eq-field textarea { min-height: 88px; resize: vertical; line-height: 1.55; }
        .eq-taxonomy-custom { display: grid; gap: 7px; margin-top: 4px; }
        .eq-taxonomy-custom[hidden] { display: none; }
        .eq-description textarea { min-height: 110px; }
        .eq-guide-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px 18px; }
        .eq-list { min-width: 0; }
        .eq-list__rows { display: grid; gap: 9px; }
        .eq-list__row { display: grid; grid-template-columns: 28px minmax(0, 1fr) auto; gap: 9px; align-items: center; }
        .eq-list__number { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 50%; background: var(--accent-tint); color: var(--accent); font-size: 12px; font-weight: 800; }
        .eq-list__row input { min-width: 0; }
        .eq-list__remove { border: 1px solid rgba(239,68,68,.35); border-radius: 7px; background: transparent; color: var(--danger); padding: 9px 11px; cursor: pointer; font-size: 11px; font-weight: 700; }
        .eq-list__remove:hover { background: rgba(239,68,68,.1); }
        .eq-list__add { justify-self: start; margin-top: 3px; padding: 8px 12px; }
        .eq-help { color: var(--muted); font-size: 11px; line-height: 1.45; }
        .eq-upload { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 20px; align-items: center; }
        .eq-upload__preview { position: relative; width: 220px; aspect-ratio: 4 / 3; border: 1px dashed var(--border); border-radius: 10px; background: var(--panel-soft); overflow: hidden; cursor: pointer; }
        .eq-upload__preview:hover { border-color: var(--accent); }
        .eq-upload__preview img { width: 100%; height: 100%; object-fit: cover; display: none; }
        .eq-upload__placeholder { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; color: var(--muted); text-align: center; padding: 18px; }
        .eq-upload__icon { font-size: 25px; color: var(--accent); }
        .eq-upload__copy { display: grid; gap: 12px; align-content: center; }
        .eq-upload__buttons { display: flex; gap: 9px; flex-wrap: wrap; }
        .eq-file-input { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; }
        .eq-toggle-row { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 15px 16px; border: 1px solid var(--border); border-radius: 10px; background: var(--panel-soft); }
        .eq-toggle-row__title { display: block; font-size: 13px; font-weight: 800; }
        .eq-toggle-row__sub { display: block; margin-top: 4px; color: var(--muted); font-size: 11px; }
        .eq-switch { position: relative; width: 48px; height: 26px; flex: 0 0 auto; }
        .eq-switch input { position: absolute; opacity: 0; pointer-events: none; }
        .eq-switch__track { position: absolute; inset: 0; border-radius: 999px; background: var(--border); cursor: pointer; transition: .2s ease; }
        .eq-switch__track::after { content: ''; position: absolute; width: 20px; height: 20px; left: 3px; top: 3px; border-radius: 50%; background: #fff; transition: .2s ease; }
        .eq-switch input:checked + .eq-switch__track { background: var(--accent); }
        .eq-switch input:checked + .eq-switch__track::after { transform: translateX(22px); background: var(--on-accent); }
        .eq-form__footer { display: flex; justify-content: flex-end; gap: 10px; padding-top: 2px; }
        .eq-submit[disabled] { opacity: .65; cursor: wait; transform: none; }
        @media (max-width: 760px) {
            .eq-create__header { align-items: flex-start; flex-direction: column; }
            .eq-create__actions { width: 100%; }
            .eq-create__actions .btn { flex: 1; }
            .eq-grid, .eq-guide-grid { grid-template-columns: 1fr; }
            .eq-upload { grid-template-columns: 1fr; }
            .eq-upload__preview { width: 100%; max-width: 320px; }
            .eq-form__footer .btn { flex: 1; }
        }
    </style>

    <div class="eq-create eq-editor">
        <div class="eq-create__header">
            <div>
                <h2 class="eq-create__title">Tambah Alat</h2>
                <p class="eq-create__crumb">Alat Gym / Tambah Alat</p>
            </div>
            <div class="eq-create__actions">
                <a href="{{ route('admin.equipments.index') }}" class="btn btn-secondary">Kembali</a>
                <button type="submit" form="equipmentCreateForm" class="btn btn-primary eq-submit" data-submit-equipment>Simpan Alat</button>
            </div>
        </div>

        <form id="equipmentCreateForm" method="POST" action="{{ $action }}" enctype="multipart/form-data" class="eq-form" data-equipment-form>
            @csrf

            <section class="eq-card">
                <div class="eq-card__head">
                    <span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h10"/></svg></span>
                    <div><h3 class="eq-card__title">Informasi Dasar</h3><p class="eq-card__sub">Identitas dan klasifikasi utama alat.</p></div>
                </div>
                <div class="eq-grid">
                    <div class="eq-field"><label for="name">Nama Alat</label><input id="name" name="name" value="{{ old('name') }}" required><span class="eq-help">Nama yang mudah dikenali oleh admin dan member.</span>@error('name')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="eq-field"><label for="slug">Slug</label><input id="slug" name="slug" value="{{ old('slug') }}"><span class="eq-help">Opsional, dibuat otomatis dari nama jika kosong.</span>@error('slug')<div class="error">{{ $message }}</div>@enderror</div>
                    @include('admin.equipments.partials.taxonomy-fields')
                    <div class="eq-field"><label for="focus">Fokus Latihan</label><input id="focus" name="focus" value="{{ old('focus') }}" required><span class="eq-help">Contoh: dada, punggung, kardio.</span>@error('focus')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="eq-field"><label for="status">Status Alat</label><select id="status" name="status"><option value="available" {{ old('status', 'available') === 'available' ? 'selected' : '' }}>Tersedia</option><option value="maintenance" {{ old('status') === 'maintenance' ? 'selected' : '' }}>Maintenance</option><option value="broken" {{ old('status') === 'broken' ? 'selected' : '' }}>Rusak</option></select>@error('status')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="eq-field"><label for="stage_label">Label Tahap</label><input id="stage_label" name="stage_label" value="{{ old('stage_label') }}"><span class="eq-help">Contoh: Pemanasan, Latihan Utama, Pendinginan.</span>@error('stage_label')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="eq-field"><label for="usage_window">Durasi/Waktu Penggunaan</label><input id="usage_window" name="usage_window" value="{{ old('usage_window') }}"><span class="eq-help">Contoh: 10–15 menit per sesi.</span>@error('usage_window')<div class="error">{{ $message }}</div>@enderror</div>
                    <div class="eq-field"><label for="best_for">Cocok Untuk</label><input id="best_for" name="best_for" value="{{ old('best_for') }}"><span class="eq-help">Contoh: pemula, pembakaran lemak, pembentukan otot.</span>@error('best_for')<div class="error">{{ $message }}</div>@enderror</div>
                </div>
            </section>

            <section class="eq-card eq-description">
                <div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M5 4h14v16H5zM8 8h8M8 12h8M8 16h5"/></svg></span><div><h3 class="eq-card__title">Deskripsi Alat</h3><p class="eq-card__sub">Ringkasan fungsi dan karakteristik alat.</p></div></div>
                <div class="eq-field"><label for="description">Deskripsi Alat</label><div class="eq-description-wrap"><textarea id="description" name="description" maxlength="5000" required data-description>{{ old('description') }}</textarea><span class="eq-character-count" data-description-count>0 karakter</span></div><span class="eq-help">Jelaskan fungsi utama dan cara penggunaan alat secara ringkas.</span>@error('description')<div class="error">{{ $message }}</div>@enderror</div>
            </section>

            @include('admin.equipments.partials.movement-list', ['movements' => $movementRows])

            <section class="eq-card">
                <div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M4 6h4l2-2h4l2 2h4v14H4z"/><circle cx="12" cy="13" r="3"/></svg></span><div><h3 class="eq-card__title">Foto Alat</h3><p class="eq-card__sub">Foto digunakan pada seluruh tampilan aplikasi.</p></div></div>
                <div class="eq-upload">
                    <label for="image" class="eq-upload__preview" aria-label="Pilih foto alat">
                        <img id="equipmentPhotoPreview" src="" alt="Preview foto alat">
                        <span id="equipmentPhotoPlaceholder" class="eq-upload__placeholder"><span class="eq-upload__icon">↥</span><strong>Klik untuk memilih foto</strong><span>Pratinjau foto alat</span></span>
                    </label>
                    <div class="eq-upload__copy eq-upload__details">
                        <input id="image" class="eq-file-input" type="file" name="image" accept="image/png,image/jpeg,image/webp">
                        <dl class="eq-file-meta"><dt>Nama file</dt><dd data-file-name>Belum ada file</dd><dt>Ukuran</dt><dd data-file-size>-</dd><dt>Format</dt><dd>JPG, PNG, WebP</dd></dl>
                        <div class="eq-upload__buttons"><button type="button" class="btn btn-secondary" data-change-photo>Ganti</button><button type="button" class="btn btn-danger" data-remove-photo hidden>Hapus</button></div>
                        <div class="eq-help">Format JPG, PNG, atau WebP. Ukuran maksimal 4 MB.</div>
                        @error('image')<div class="error">{{ $message }}</div>@enderror
                    </div>
                </div>
            </section>

            <section class="eq-card">
                <div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M6 4h12v16H6zM9 8h6M9 12h6M9 16h4"/></svg></span><div><h3 class="eq-card__title">Panduan Penggunaan</h3><p class="eq-card__sub">Susun informasi penggunaan alat dalam item yang mudah dipindai.</p></div></div>
                <div class="eq-guide-grid">
                    @include('admin.equipments.partials.dynamic-list', ['name' => 'key_benefits_text', 'label' => 'Manfaat Utama', 'value' => $keyBenefitsText, 'placeholder' => 'Contoh: meningkatkan kekuatan otot', 'addLabel' => 'Tambah Manfaat', 'helper' => 'Tambahkan setiap manfaat sebagai item terpisah.'])
                    @include('admin.equipments.partials.dynamic-list', ['name' => 'usage_flow_text', 'label' => 'Langkah Penggunaan', 'value' => $usageFlowText, 'placeholder' => 'Contoh: atur posisi duduk', 'addLabel' => 'Tambah Langkah', 'helper' => 'Urutkan langkah penggunaan dari awal hingga selesai.'])
                    @include('admin.equipments.partials.dynamic-list', ['name' => 'safety_notes_text', 'label' => 'Panduan Keamanan', 'value' => $safetyNotesText, 'placeholder' => 'Contoh: gunakan beban sesuai kemampuan', 'addLabel' => 'Tambah Catatan', 'helper' => 'Tambahkan catatan untuk membantu penggunaan alat yang aman.'])
                </div>
            </section>

            <section class="eq-card">
                <div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3"/></svg></span><div><h3 class="eq-card__title">Pengaturan</h3><p class="eq-card__sub">Atur visibilitas alat pada aplikasi.</p></div></div>
                <div class="eq-toggle-row">
                    <span><span class="eq-toggle-row__title">Alat Aktif</span><span class="eq-toggle-row__sub">Alat aktif dapat ditampilkan pada aplikasi.</span></span>
                    <label class="eq-switch"><input type="hidden" name="is_active" value="0"><input type="checkbox" name="is_active" value="1" {{ old('is_active', true) ? 'checked' : '' }}><span class="eq-switch__track"></span></label>
                </div>
            </section>

            <div class="eq-form__footer">
                <a href="{{ route('admin.equipments.index') }}" class="btn btn-secondary">Kembali</a>
                <button type="submit" class="btn btn-primary eq-submit" data-submit-equipment>Simpan Alat</button>
            </div>
        </form>
    </div>

    <script>
        (() => {
            const form = document.querySelector('[data-equipment-form]');
            const input = document.getElementById('image');
            const preview = document.getElementById('equipmentPhotoPreview');
            const placeholder = document.getElementById('equipmentPhotoPlaceholder');
            const remove = document.querySelector('[data-remove-photo]');
            const fileName = document.querySelector('[data-file-name]');
            const fileSize = document.querySelector('[data-file-size]');
            const description = document.querySelector('[data-description]');
            const descriptionCount = document.querySelector('[data-description-count]');
            let previewUrl = null;
            const clearPreview = () => {
                if (previewUrl) URL.revokeObjectURL(previewUrl);
                previewUrl = null; input.value = ''; preview.removeAttribute('src'); preview.style.display = 'none';
                placeholder.style.display = 'flex'; remove.hidden = true; fileName.textContent = 'Belum ada file'; fileSize.textContent = '-';
            };
            input.addEventListener('change', () => {
                const file = input.files?.[0];
                if (!file) return clearPreview();
                if (previewUrl) URL.revokeObjectURL(previewUrl);
                previewUrl = URL.createObjectURL(file); preview.src = previewUrl; preview.style.display = 'block';
                placeholder.style.display = 'none'; remove.hidden = false; fileName.textContent = file.name; fileSize.textContent = `${(file.size / 1024 / 1024).toFixed(2)} MB`;
            });
            document.querySelector('[data-change-photo]').addEventListener('click', () => input.click());
            remove.addEventListener('click', clearPreview);
            const updateDescriptionCount = () => { descriptionCount.textContent = `${description.value.length} karakter`; };
            description.addEventListener('input', updateDescriptionCount); updateDescriptionCount();
            document.querySelectorAll('[data-taxonomy-field]').forEach((field) => {
                const select = field.querySelector('[data-taxonomy-select]');
                const custom = field.querySelector('[data-taxonomy-custom]');
                const input = field.querySelector('[data-taxonomy-input]');
                const value = field.querySelector('[data-taxonomy-value]');
                const sync = () => {
                    const isOther = select.value === '{{ $equipmentOtherValue }}';
                    custom.hidden = !isOther;
                    input.required = isOther;
                    if (!isOther) input.value = '';
                    value.value = isOther ? input.value : select.value;
                };
                select.addEventListener('change', sync);
                input.addEventListener('input', sync);
                sync();
            });
            document.querySelectorAll('[data-dynamic-list]').forEach((list) => {
                const rows = list.querySelector('[data-list-rows]');
                const payload = list.querySelector('[data-list-payload]');
                const update = () => {
                    const rowElements = [...rows.querySelectorAll('[data-list-row]')];
                    rowElements.forEach((row, index) => { row.querySelector('[data-list-number]').textContent = index + 1; });
                    payload.value = rowElements.map((row) => row.querySelector('[data-list-input]').value.trim()).filter(Boolean).join('\n');
                };
                const addRow = (value = '') => {
                    const row = document.createElement('div');
                    row.className = 'eq-list__row'; row.dataset.listRow = '';
                    row.innerHTML = `<span class="eq-list__number" data-list-number></span><input type="text" data-list-input><button type="button" class="eq-list__remove" data-list-remove>Hapus</button>`;
                    row.querySelector('[data-list-input]').value = value; rows.appendChild(row); update();
                };
                rows.addEventListener('input', update);
                rows.addEventListener('click', (event) => {
                    if (!event.target.matches('[data-list-remove]')) return;
                    event.target.closest('[data-list-row]').remove();
                    if (!rows.querySelector('[data-list-row]')) addRow();
                    update();
                });
                list.querySelector('[data-list-add]').addEventListener('click', () => addRow());
                form.addEventListener('submit', update);
                update();
            });
            form.addEventListener('submit', () => {
                document.querySelectorAll('[data-submit-equipment]').forEach((button) => { button.disabled = true; button.textContent = 'Menyimpan Alat...'; });
            });
        })();
    </script>
@endsection
