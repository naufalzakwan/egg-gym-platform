@php
    $categoryValue = old('category', $equipment->category);
    $categoryIsStandard = in_array($categoryValue, $equipmentCategories, true);
    $categorySelection = old('category_selection', $categoryIsStandard || blank($categoryValue) ? $categoryValue : $equipmentOtherValue);
    $categoryCustom = old('category_custom', $categoryIsStandard ? '' : $categoryValue);
    $difficultyValue = old('difficulty', $equipment->difficulty);
    $difficultyIsStandard = in_array($difficultyValue, $equipmentDifficulties, true);
    $difficultySelection = old('difficulty_selection', $difficultyIsStandard || blank($difficultyValue) ? $difficultyValue : $equipmentOtherValue);
    $difficultyCustom = old('difficulty_custom', $difficultyIsStandard ? '' : $difficultyValue);
@endphp

<div class="eq-field field" data-taxonomy-field>
    <label for="category_selection">Kategori</label>
    <input type="hidden" name="category" value="{{ $categoryValue }}" data-taxonomy-value>
    <select id="category_selection" name="category_selection" required data-taxonomy-select>
        <option value="">Pilih kategori</option>
        @foreach($equipmentCategories as $categoryOption)
            <option value="{{ $categoryOption }}" {{ $categorySelection === $categoryOption ? 'selected' : '' }}>{{ $categoryOption }}</option>
        @endforeach
        <option value="{{ $equipmentOtherValue }}" {{ $categorySelection === $equipmentOtherValue ? 'selected' : '' }}>Lainnya</option>
    </select>
    @error('category_selection')<div class="error">{{ $message }}</div>@enderror
    <div class="eq-taxonomy-custom" data-taxonomy-custom {{ $categorySelection === $equipmentOtherValue ? '' : 'hidden' }}>
        <label for="category_custom">Kategori Lainnya</label>
        <input id="category_custom" name="category_custom" value="{{ $categoryCustom }}" data-taxonomy-input>
        @error('category_custom')<div class="error">{{ $message }}</div>@enderror
    </div>
</div>

<div class="eq-field field" data-taxonomy-field>
    <label for="difficulty_selection">Tingkat Kesulitan</label>
    <input type="hidden" name="difficulty" value="{{ $difficultyValue }}" data-taxonomy-value>
    <select id="difficulty_selection" name="difficulty_selection" data-taxonomy-select>
        <option value="">Pilih tingkat kesulitan (opsional)</option>
        @foreach($equipmentDifficulties as $difficultyOption)
            <option value="{{ $difficultyOption }}" {{ $difficultySelection === $difficultyOption ? 'selected' : '' }}>{{ $difficultyOption }}</option>
        @endforeach
        <option value="{{ $equipmentOtherValue }}" {{ $difficultySelection === $equipmentOtherValue ? 'selected' : '' }}>Lainnya</option>
    </select>
    @error('difficulty_selection')<div class="error">{{ $message }}</div>@enderror
    <div class="eq-taxonomy-custom" data-taxonomy-custom {{ $difficultySelection === $equipmentOtherValue ? '' : 'hidden' }}>
        <label for="difficulty_custom">Tingkat Kesulitan Lainnya</label>
        <input id="difficulty_custom" name="difficulty_custom" value="{{ $difficultyCustom }}" data-taxonomy-input>
        @error('difficulty_custom')<div class="error">{{ $message }}</div>@enderror
    </div>
</div>
