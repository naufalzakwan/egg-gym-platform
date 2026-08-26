@extends('admin.layouts.app')

@php
    $title = $pageTitle . ' - EggGym Admin';
    $pageHeading = $pageTitle;
    $pageSubheading = 'Form master data equipment untuk fondasi admin web.';
    $keyBenefitsText = old('key_benefits_text', implode(PHP_EOL, $equipment->key_benefits_json ?? []));
    $usageFlowText = old('usage_flow_text', implode(PHP_EOL, $equipment->usage_flow_json ?? []));
    $safetyNotesText = old('safety_notes_text', implode(PHP_EOL, $equipment->safety_notes_json ?? []));
    $movementRows = old('movements', $equipment->movements);
@endphp

@section('content')
    @include('admin.equipments.partials.editor-styles')
    <div class="eq-editor">
        <div class="eq-create__header">
            <div><h2 class="eq-create__title">Edit Alat</h2><p class="eq-create__crumb">Alat Gym / Edit Alat</p></div>
            <div class="eq-create__actions"><a href="{{ route('admin.equipments.index') }}" class="btn btn-secondary">Kembali</a><button type="submit" form="equipmentEditForm" class="btn btn-primary" data-submit-equipment>Simpan Alat</button></div>
        </div>
    <form id="equipmentEditForm" method="POST" action="{{ $action }}" class="eq-form" enctype="multipart/form-data" data-equipment-form>
        @csrf
        @if ($method !== 'POST')
            @method($method)
        @endif

        <section class="eq-card">
            <div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h10"/></svg></span><div><h3 class="eq-card__title">Informasi Dasar</h3><p class="eq-card__sub">Identitas dan klasifikasi utama alat.</p></div></div>
        <div class="form-grid eq-grid">
            <div class="field">
                <label for="name">Nama Alat</label>
                <input id="name" type="text" name="name" value="{{ old('name', $equipment->name) }}" required>
                <div class="help">Nama yang mudah dikenali oleh admin dan member.</div>
                @error('name')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="slug">Slug</label>
                <input id="slug" type="text" name="slug" value="{{ old('slug', $equipment->slug) }}">
                <div class="help">Opsional. Jika kosong akan dibuat otomatis dari nama.</div>
                @error('slug')<div class="error">{{ $message }}</div>@enderror
            </div>

            @include('admin.equipments.partials.taxonomy-fields')

            <div class="field">
                <label for="focus">Fokus Latihan</label>
                <input id="focus" type="text" name="focus" value="{{ old('focus', $equipment->focus) }}" required>
                <div class="help">Contoh: dada, punggung, kardio.</div>
                @error('focus')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="status">Status Alat</label>
                @php $selectedStatus = old('status', $equipment->status ?? 'available'); @endphp
                <select id="status" name="status">
                    <option value="available" {{ $selectedStatus === 'available' ? 'selected' : '' }}>Tersedia</option>
                    <option value="maintenance" {{ $selectedStatus === 'maintenance' ? 'selected' : '' }}>Maintenance</option>
                    <option value="broken" {{ $selectedStatus === 'broken' ? 'selected' : '' }}>Rusak</option>
                </select>
                @error('status')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="stage_label">Label Tahap</label>
                <input id="stage_label" type="text" name="stage_label" value="{{ old('stage_label', $equipment->stage_label) }}">
                <div class="help">Contoh: Pemanasan, Latihan Utama, Pendinginan.</div>
                @error('stage_label')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="usage_window">Durasi/Waktu Penggunaan</label>
                <input id="usage_window" type="text" name="usage_window" value="{{ old('usage_window', $equipment->usage_window) }}">
                <div class="help">Contoh: 10–15 menit per sesi.</div>
                @error('usage_window')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div class="field">
                <label for="best_for">Cocok Untuk</label>
                <input id="best_for" type="text" name="best_for" value="{{ old('best_for', $equipment->best_for) }}">
                <div class="help">Contoh: pemula, pembakaran lemak, pembentukan otot.</div>
                @error('best_for')<div class="error">{{ $message }}</div>@enderror
            </div>


        </div></section>

            <section class="eq-card eq-description"><div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M5 4h14v16H5zM8 8h8M8 12h8M8 16h5"/></svg></span><div><h3 class="eq-card__title">Deskripsi Alat</h3><p class="eq-card__sub">Ringkasan fungsi dan karakteristik alat.</p></div></div>
            <div class="field field-full">
                <label for="description">Deskripsi Alat</label>
                <div class="eq-description-wrap"><textarea id="description" name="description" maxlength="5000" required data-description>{{ old('description', $equipment->description) }}</textarea><span class="eq-character-count" data-description-count>0 karakter</span></div>
                <div class="help">Jelaskan fungsi utama dan cara penggunaan alat secara ringkas.</div>
                @error('description')<div class="error">{{ $message }}</div>@enderror
            </div>
            </section>

            <section class="eq-card"><div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M4 6h4l2-2h4l2 2h4v14H4z"/><circle cx="12" cy="13" r="3"/></svg></span><div><h3 class="eq-card__title">Foto Alat</h3><p class="eq-card__sub">Perbarui foto alat yang tampil pada aplikasi.</p></div></div>
                <div class="eq-upload equipment-photo">
                    <label for="image" class="eq-upload__preview equipment-photo__preview" id="equipmentPhotoPreviewWrap">
                        @if (!empty($equipment->image_url))
                            <img id="equipmentPhotoPreview" src="{{ $equipment->image_url }}" alt="Foto {{ $equipment->name }}">
                        @else
                            <img id="equipmentPhotoPreview" src="" alt="Preview foto alat" style="display: none;">
                            <span id="equipmentPhotoPlaceholder" class="eq-upload__placeholder"><span class="eq-upload__icon">↥</span><strong>Klik untuk memilih foto</strong><span>Pratinjau foto alat</span></span>
                        @endif
                    </label>
                    <div class="eq-upload__details equipment-photo__control">
                        <input id="image" class="eq-file-input" type="file" name="image" accept="image/png,image/jpeg,image/jpg,image/webp" onchange="previewEquipmentPhoto(event)">
                        <dl class="eq-file-meta"><dt>Nama file</dt><dd data-file-name>{{ $equipment->image_path ? basename($equipment->image_path) : 'Belum ada file' }}</dd><dt>Ukuran baru</dt><dd data-file-size>-</dd><dt>Format</dt><dd>JPG, PNG, WebP</dd></dl>
                        <div class="eq-upload__buttons"><button type="button" class="btn btn-secondary" data-change-photo>Ganti Foto</button></div>
                        <div class="help">Format JPG, PNG, atau WebP. Ukuran maksimal 4 MB.</div>
                        @error('image')<div class="error">{{ $message }}</div>@enderror
                    </div>
                </div>
            </section>

            <section class="eq-card"><div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M6 4h12v16H6zM9 8h6M9 12h6M9 16h4"/></svg></span><div><h3 class="eq-card__title">Panduan Penggunaan</h3><p class="eq-card__sub">Susun informasi penggunaan alat dalam item yang mudah dipindai.</p></div></div><div class="eq-guide-grid">
            @include('admin.equipments.partials.dynamic-list', ['name' => 'key_benefits_text', 'label' => 'Manfaat Utama', 'value' => $keyBenefitsText, 'placeholder' => 'Contoh: meningkatkan kekuatan otot', 'addLabel' => 'Tambah Manfaat', 'helper' => 'Tambahkan setiap manfaat sebagai item terpisah.'])
            @include('admin.equipments.partials.dynamic-list', ['name' => 'usage_flow_text', 'label' => 'Langkah Penggunaan', 'value' => $usageFlowText, 'placeholder' => 'Contoh: atur posisi duduk', 'addLabel' => 'Tambah Langkah', 'helper' => 'Urutkan langkah penggunaan dari awal hingga selesai.'])
            @include('admin.equipments.partials.dynamic-list', ['name' => 'safety_notes_text', 'label' => 'Panduan Keamanan', 'value' => $safetyNotesText, 'placeholder' => 'Contoh: gunakan beban sesuai kemampuan', 'addLabel' => 'Tambah Catatan', 'helper' => 'Tambahkan catatan untuk membantu penggunaan alat yang aman.'])
            </div></section>

            @include('admin.equipments.partials.movement-list', ['movements' => $movementRows])

            <section class="eq-card"><div class="eq-card__head"><span class="eq-card__icon"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3"/></svg></span><div><h3 class="eq-card__title">Pengaturan</h3><p class="eq-card__sub">Atur visibilitas alat pada aplikasi.</p></div></div><div class="eq-toggle-row"><span><span class="eq-toggle-row__title">Alat Aktif</span><span class="eq-toggle-row__sub">Alat aktif dapat ditampilkan pada aplikasi.</span></span><label class="eq-switch"><input type="hidden" name="is_active" value="0"><input type="checkbox" name="is_active" value="1" {{ old('is_active', $equipment->is_active ?? true) ? 'checked' : '' }}><span class="eq-switch__track"></span></label></div></section>

        <div class="actions eq-form__footer">
            <a href="{{ route('admin.equipments.index') }}" class="btn btn-secondary">Kembali</a>
            <button type="submit" class="btn btn-primary" data-submit-equipment>Simpan Alat</button>
        </div>
    </form>
    </div>

    <style>
        .eq-create__header { display: flex; align-items: center; justify-content: space-between; gap: 18px; margin-bottom: 22px; }
        .eq-create__title { margin: 0; font-size: 24px; font-weight: 800; letter-spacing: 1.4px; text-transform: uppercase; }
        .eq-create__crumb { margin: 7px 0 0; color: var(--muted); font-size: 13px; }
        .eq-create__actions { display: flex; gap: 10px; flex-wrap: wrap; }
        .eq-form { display: grid; gap: 22px; }
        .eq-grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 16px 18px; }
        .eq-description textarea { min-height: 110px; resize: vertical; }
        .eq-guide-grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 16px 18px; }
        .eq-taxonomy-custom { display: grid; gap: 7px; margin-top: 4px; }
        .eq-taxonomy-custom[hidden] { display: none; }
        .eq-upload__preview img { width: 100%; height: 100%; object-fit: cover; }
        .eq-upload__placeholder { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; color: var(--muted); text-align: center; }
        .eq-upload__buttons { display: flex; gap: 9px; }
        .eq-file-input { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; }
        .eq-toggle-row { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 15px 16px; border: 1px solid var(--border); border-radius: 10px; background: var(--panel-soft); }
        .eq-toggle-row__title { display: block; font-size: 13px; font-weight: 800; }.eq-toggle-row__sub { display:block;margin-top:4px;color:var(--muted);font-size:11px; }
        .eq-switch { position:relative;width:48px;height:26px;flex:0 0 auto; }.eq-switch input{position:absolute;opacity:0}.eq-switch__track{position:absolute;inset:0;border-radius:999px;background:var(--border);cursor:pointer}.eq-switch__track::after{content:'';position:absolute;width:20px;height:20px;left:3px;top:3px;border-radius:50%;background:#fff;transition:.2s}.eq-switch input:checked + .eq-switch__track{background:var(--accent)}.eq-switch input:checked + .eq-switch__track::after{transform:translateX(22px);background:var(--on-accent)}
        .equipment-photo {
            display: flex;
            gap: 20px;
            align-items: flex-start;
            flex-wrap: wrap;
        }
        .equipment-photo__preview {
            width: 220px;
            height: 165px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: var(--panel-soft);
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }
        .equipment-photo__preview img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .equipment-photo__placeholder {
            color: var(--text-muted);
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 1px;
            text-transform: uppercase;
        }
        .equipment-photo__control {
            flex: 1;
            min-width: 220px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .eq-taxonomy-custom { display: grid; gap: 8px; margin-top: 4px; }
        .eq-taxonomy-custom[hidden] { display: none; }
        .eq-list { min-width: 0; }
        .eq-list__rows { display: grid; gap: 9px; }
        .eq-list__row { display: grid; grid-template-columns: 28px minmax(0, 1fr) auto; gap: 9px; align-items: center; }
        .eq-list__number { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 50%; background: var(--accent-tint); color: var(--accent); font-size: 12px; font-weight: 800; }
        .eq-list__remove { border: 1px solid rgba(239,68,68,.35); border-radius: 7px; background: transparent; color: var(--danger); padding: 9px 11px; cursor: pointer; font-size: 11px; font-weight: 700; }
        .eq-list__add { align-self: flex-start; margin-top: 3px; padding: 8px 12px; }
        @media(max-width:760px){.eq-create__header{align-items:flex-start;flex-direction:column}.eq-create__actions{width:100%}.eq-create__actions .btn{flex:1}.eq-grid,.eq-guide-grid{grid-template-columns:1fr}.eq-form__footer .btn{flex:1}}
    </style>

    <script>
        document.querySelectorAll('[data-taxonomy-field]').forEach(function (field) {
            var select = field.querySelector('[data-taxonomy-select]');
            var custom = field.querySelector('[data-taxonomy-custom]');
            var input = field.querySelector('[data-taxonomy-input]');
            var value = field.querySelector('[data-taxonomy-value]');
            function syncTaxonomyField() {
                var isOther = select.value === '{{ $equipmentOtherValue }}';
                custom.hidden = !isOther;
                input.required = isOther;
                if (!isOther) input.value = '';
                value.value = isOther ? input.value : select.value;
            }
            select.addEventListener('change', syncTaxonomyField);
            input.addEventListener('input', syncTaxonomyField);
            syncTaxonomyField();
        });

        document.querySelectorAll('[data-dynamic-list]').forEach(function (list) {
            var rows = list.querySelector('[data-list-rows]');
            var payload = list.querySelector('[data-list-payload]');
            function updateDynamicList() {
                var rowElements = Array.from(rows.querySelectorAll('[data-list-row]'));
                rowElements.forEach(function (row, index) {
                    row.querySelector('[data-list-number]').textContent = index + 1;
                });
                payload.value = rowElements.map(function (row) {
                    return row.querySelector('[data-list-input]').value.trim();
                }).filter(Boolean).join('\n');
            }
            function addDynamicRow(value) {
                var row = document.createElement('div');
                row.className = 'eq-list__row';
                row.dataset.listRow = '';
                row.innerHTML = '<span class="eq-list__number" data-list-number></span><input type="text" data-list-input><button type="button" class="eq-list__remove" data-list-remove>Hapus</button>';
                row.querySelector('[data-list-input]').value = value || '';
                rows.appendChild(row);
                updateDynamicList();
            }
            rows.addEventListener('input', updateDynamicList);
            rows.addEventListener('click', function (event) {
                if (!event.target.matches('[data-list-remove]')) return;
                event.target.closest('[data-list-row]').remove();
                if (!rows.querySelector('[data-list-row]')) addDynamicRow('');
                updateDynamicList();
            });
            list.querySelector('[data-list-add]').addEventListener('click', function () { addDynamicRow(''); });
            list.closest('form').addEventListener('submit', updateDynamicList);
            updateDynamicList();
        });

        function previewEquipmentPhoto(event) {
            var file = event.target.files && event.target.files[0];
            var img = document.getElementById('equipmentPhotoPreview');
            var placeholder = document.getElementById('equipmentPhotoPlaceholder');
            var fileName = document.querySelector('[data-file-name]');
            var fileSize = document.querySelector('[data-file-size]');
            if (!file || !img) {
                return;
            }
            var reader = new FileReader();
            reader.onload = function (e) {
                img.src = e.target.result;
                img.style.display = 'block';
                fileName.textContent = file.name;
                fileSize.textContent = (file.size / 1024 / 1024).toFixed(2) + ' MB';
                if (placeholder) {
                    placeholder.style.display = 'none';
                }
            };
            reader.readAsDataURL(file);
        }
        document.querySelector('[data-change-photo]').addEventListener('click', function () { document.getElementById('image').click(); });
        var description = document.querySelector('[data-description]');
        var descriptionCount = document.querySelector('[data-description-count]');
        function updateDescriptionCount(){ descriptionCount.textContent = description.value.length + ' karakter'; }
        description.addEventListener('input', updateDescriptionCount); updateDescriptionCount();
        document.querySelector('[data-equipment-form]').addEventListener('submit', function () {
            document.querySelectorAll('[data-submit-equipment]').forEach(function(button){ button.disabled = true; button.textContent = 'Menyimpan Alat...'; });
        });
    </script>
@endsection
