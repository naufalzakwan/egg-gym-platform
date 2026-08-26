@php
    $movementItems = collect($movements ?? [])
        ->map(fn ($movement) => [
            'movement_name' => is_array($movement) ? ($movement['movement_name'] ?? '') : $movement->movement_name,
            'target_area' => is_array($movement) ? ($movement['target_area'] ?? '') : $movement->target_area,
        ])
        ->values();
    if ($movementItems->isEmpty()) $movementItems = collect([['movement_name' => '', 'target_area' => '']]);
@endphp

<section class="eq-card" data-movement-list>
    <div class="eq-card__head">
        <span class="eq-card__icon"><svg viewBox="0 0 24 24"><path d="M4 12h16M7 8l-3 4 3 4M17 8l3 4-3 4"/></svg></span>
        <div><h3 class="eq-card__title">Gerakan yang Bisa Dilakukan</h3><p class="eq-card__sub">Tambahkan setiap gerakan beserta bagian otot atau target latihannya.</p></div>
    </div>
    <div class="eq-movement__rows" data-movement-rows>
        @foreach($movementItems as $movement)
            <div class="eq-movement__row" data-movement-row>
                <span class="eq-list__number" data-movement-number>{{ $loop->iteration }}</span>
                <div class="eq-field field"><label>Nama Gerakan</label><input type="text" name="movements[{{ $loop->index }}][movement_name]" value="{{ $movement['movement_name'] }}" placeholder="Contoh: Cable Fly" maxlength="255" data-movement-name></div>
                <div class="eq-field field"><label>Bagian Otot / Target</label><input type="text" name="movements[{{ $loop->index }}][target_area]" value="{{ $movement['target_area'] }}" placeholder="Contoh: Chest" maxlength="255" data-movement-target></div>
                <button type="button" class="eq-list__remove eq-movement__remove" data-movement-remove aria-label="Hapus gerakan" title="Hapus gerakan">Hapus</button>
            </div>
        @endforeach
    </div>
    <button type="button" class="btn btn-secondary eq-list__add" data-movement-add>+ Tambah Gerakan</button>
    <div class="eq-help help">Baris yang dibuat wajib memiliki nama gerakan dan target otot. Baris kosong tidak akan disimpan.</div>
    @error('movements')<div class="error">{{ $message }}</div>@enderror
    @error('movements.*.movement_name')<div class="error">{{ $message }}</div>@enderror
    @error('movements.*.target_area')<div class="error">{{ $message }}</div>@enderror
</section>

<script>
    (() => {
        const list = document.querySelector('[data-movement-list]');
        if (!list) return;
        const rows = list.querySelector('[data-movement-rows]');
        const reindex = () => {
            [...rows.querySelectorAll('[data-movement-row]')].forEach((row, index) => {
                row.querySelector('[data-movement-number]').textContent = index + 1;
                row.querySelector('[data-movement-name]').name = `movements[${index}][movement_name]`;
                row.querySelector('[data-movement-target]').name = `movements[${index}][target_area]`;
            });
        };
        const addRow = () => {
            const row = document.createElement('div');
            row.className = 'eq-movement__row';
            row.dataset.movementRow = '';
            row.innerHTML = '<span class="eq-list__number" data-movement-number></span><div class="eq-field field"><label>Nama Gerakan</label><input type="text" placeholder="Contoh: Cable Fly" maxlength="255" data-movement-name></div><div class="eq-field field"><label>Bagian Otot / Target</label><input type="text" placeholder="Contoh: Chest" maxlength="255" data-movement-target></div><button type="button" class="eq-list__remove eq-movement__remove" data-movement-remove aria-label="Hapus gerakan" title="Hapus gerakan">Hapus</button>';
            rows.appendChild(row);
            reindex();
            row.querySelector('[data-movement-name]').focus();
        };
        rows.addEventListener('click', (event) => {
            if (!event.target.matches('[data-movement-remove]')) return;
            event.target.closest('[data-movement-row]').remove();
            if (!rows.querySelector('[data-movement-row]')) addRow();
            reindex();
        });
        list.querySelector('[data-movement-add]').addEventListener('click', addRow);
        reindex();
    })();
</script>
