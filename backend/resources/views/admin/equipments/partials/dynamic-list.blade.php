@php
    $listItems = collect(preg_split('/\r\n|\r|\n/', (string) $value) ?: [])
        ->map(fn ($item) => trim((string) $item))
        ->filter()
        ->values();
    if ($listItems->isEmpty()) $listItems = collect(['']);
@endphp

<div class="eq-list field field-full" data-dynamic-list data-list-name="{{ $name }}">
    <label>{{ $label }}</label>
    <div class="eq-list__rows" data-list-rows>
        @foreach($listItems as $listItem)
            <div class="eq-list__row" data-list-row>
                <span class="eq-list__number" data-list-number>{{ $loop->iteration }}</span>
                <input type="text" value="{{ $listItem }}" placeholder="{{ $placeholder }}" data-list-input>
                <button type="button" class="eq-list__remove" data-list-remove aria-label="Hapus item" title="Hapus item">Hapus</button>
            </div>
        @endforeach
    </div>
    <button type="button" class="btn btn-secondary eq-list__add" data-list-add>+ {{ $addLabel }}</button>
    <textarea name="{{ $name }}" data-list-payload hidden>{{ $value }}</textarea>
    <div class="eq-help help">{{ $helper }}</div>
    @error($name)<div class="error">{{ $message }}</div>@enderror
</div>
