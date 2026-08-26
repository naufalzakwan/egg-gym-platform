<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Equipment;
use App\Services\ActivityLogger;
use App\Support\EquipmentTaxonomy;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class EquipmentController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $requestedCategory = trim((string) $request->query('category', ''));
        $category = in_array($requestedCategory, [...EquipmentTaxonomy::CATEGORIES, EquipmentTaxonomy::OTHER], true)
            ? $requestedCategory
            : '';

        $equipments = Equipment::query()
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('name', 'like', '%'.$search.'%')
                        ->orWhere('category', 'like', '%'.$search.'%')
                        ->orWhere('code', 'like', '%'.$search.'%')
                        ->orWhere('focus', 'like', '%'.$search.'%')
                        ->orWhere('status', 'like', '%'.$search.'%')
                        ->orWhere('stage_label', 'like', '%'.$search.'%')
                        ->orWhere('usage_window', 'like', '%'.$search.'%');
                });
            })
            ->when($category === EquipmentTaxonomy::OTHER, fn ($q) => $q->whereNotIn('category', EquipmentTaxonomy::CATEGORIES))
            ->when($category !== '' && $category !== EquipmentTaxonomy::OTHER, fn ($q) => $q->where('category', $category))
            ->orderBy('name')
            ->get();

        // Statistik ringkasan status (data nyata).
        $stats = [
            'total' => Equipment::query()->count(),
            'available' => Equipment::query()->where('status', 'available')->count(),
            'maintenance' => Equipment::query()->where('status', 'maintenance')->count(),
            'broken' => Equipment::query()->where('status', 'broken')->count(),
        ];

        // Alat yang butuh audit/inspeksi = maintenance + broken.
        $auditCount = $stats['maintenance'] + $stats['broken'];

        return view('admin.equipments.index', [
            'equipments' => $equipments,
            'search' => $search,
            'category' => $category,
            'stats' => $stats,
            'auditCount' => $auditCount,
            'categories' => EquipmentTaxonomy::CATEGORIES,
            'otherCategoryValue' => EquipmentTaxonomy::OTHER,
            'lastUpdated' => Equipment::query()->max('updated_at'),
        ]);
    }

    public function create(): View
    {
        return view('admin.equipments.create', [
            'equipment' => new Equipment,
            'pageTitle' => 'Tambah Equipment',
            'submitLabel' => 'Simpan Equipment',
            'action' => route('admin.equipments.store'),
            'method' => 'POST',
            ...$this->taxonomyOptions(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->normalizeMovements($request);
        $validated = $this->validateEquipment($request);

        $payload = $this->buildPayload($validated);

        // Auto-generate kode alat unik (EQ-xxx) untuk alat baru.
        $payload['code'] = $this->generateEquipmentCode();

        // Simpan foto alat bila diupload (disk 'public' → storage/app/public).
        if ($request->hasFile('image')) {
            $payload['image_path'] = $request->file('image')->store('equipments', 'public');
        }

        $equipment = DB::transaction(function () use ($payload, $validated) {
            $equipment = Equipment::create($payload);
            $this->syncMovements($equipment, $validated['movements'] ?? []);

            return $equipment;
        });

        ActivityLogger::logCreated($equipment, "Equipment baru ditambahkan: {$equipment->name}");

        return redirect()
            ->route('admin.equipments.index')
            ->with('success', 'Equipment berhasil ditambahkan.');
    }

    public function edit(Equipment $equipment): View
    {
        $equipment->load('movements');

        return view('admin.equipments.form', [
            'equipment' => $equipment,
            'pageTitle' => 'Edit Equipment',
            'submitLabel' => 'Update Equipment',
            'action' => route('admin.equipments.update', $equipment),
            'method' => 'PUT',
            ...$this->taxonomyOptions(),
        ]);
    }

    public function update(Request $request, Equipment $equipment): RedirectResponse
    {
        $this->normalizeMovements($request);
        $validated = $this->validateEquipment($request, $equipment->id);
        $oldData = $equipment->toArray();

        $payload = $this->buildPayload($validated);

        // Ganti foto bila ada upload baru; hapus foto lama agar tidak menumpuk.
        if ($request->hasFile('image')) {
            if (! empty($equipment->image_path)) {
                Storage::disk('public')->delete($equipment->image_path);
            }
            $payload['image_path'] = $request->file('image')->store('equipments', 'public');
        }

        DB::transaction(function () use ($equipment, $payload, $validated): void {
            $equipment->update($payload);
            $this->syncMovements($equipment, $validated['movements'] ?? []);
        });

        ActivityLogger::logUpdated($equipment, $oldData, "Equipment diperbarui: {$equipment->name}");

        return redirect()
            ->route('admin.equipments.index')
            ->with('success', 'Equipment berhasil diperbarui.');
    }

    public function destroy(Equipment $equipment): RedirectResponse
    {
        $name = $equipment->name;

        // Bersihkan file foto terkait dari storage saat equipment dihapus.
        if (! empty($equipment->image_path)) {
            Storage::disk('public')->delete($equipment->image_path);
        }

        ActivityLogger::logDeleted($equipment, "Equipment dihapus: {$name}");
        $equipment->delete();

        return redirect()
            ->route('admin.equipments.index')
            ->with('success', 'Equipment berhasil dihapus.');
    }

    private function validateEquipment(Request $request, ?int $equipmentId = null): array
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', 'unique:equipments,slug,'.$equipmentId],
            'category' => ['nullable', 'required_without:category_selection', 'string', 'max:50'],
            'category_selection' => ['nullable', 'required_without:category', 'string', 'in:'.implode(',', [...EquipmentTaxonomy::CATEGORIES, EquipmentTaxonomy::OTHER])],
            'category_custom' => ['nullable', 'required_if:category_selection,'.EquipmentTaxonomy::OTHER, 'string', 'max:50'],
            'description' => ['required', 'string'],
            'status' => ['nullable', 'in:available,maintenance,broken'],
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'focus' => ['required', 'string', 'max:255'],
            'stage_label' => ['nullable', 'string', 'max:255'],
            'usage_window' => ['nullable', 'string', 'max:255'],
            'best_for' => ['nullable', 'string', 'max:255'],
            'difficulty' => ['nullable', 'string', 'max:255'],
            'difficulty_selection' => ['nullable', 'string', 'in:'.implode(',', [...EquipmentTaxonomy::DIFFICULTIES, EquipmentTaxonomy::OTHER])],
            'difficulty_custom' => ['nullable', 'required_if:difficulty_selection,'.EquipmentTaxonomy::OTHER, 'string', 'max:255'],
            'key_benefits_text' => ['nullable', 'string'],
            'usage_flow_text' => ['nullable', 'string'],
            'safety_notes_text' => ['nullable', 'string'],
            'suggested_moves_text' => ['nullable', 'string'],
            'movements' => ['nullable', 'array', 'max:50'],
            'movements.*.movement_name' => ['required', 'string', 'max:255'],
            'movements.*.target_area' => ['required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if (array_key_exists('category_selection', $validated)) {
            $validated['category'] = EquipmentTaxonomy::resolve(
                $validated['category_selection'] ?? '',
                $validated['category_custom'] ?? null
            );
        }
        if (array_key_exists('difficulty_selection', $validated)) {
            $validated['difficulty'] = EquipmentTaxonomy::resolve(
                $validated['difficulty_selection'] ?? '',
                $validated['difficulty_custom'] ?? null
            );
        }

        return $validated;
    }

    private function buildPayload(array $validated): array
    {
        $name = trim((string) $validated['name']);
        $slug = trim((string) ($validated['slug'] ?? ''));

        return [
            'name' => $name,
            'slug' => $slug !== '' ? Str::slug($slug) : Str::slug($name),
            'category' => trim((string) $validated['category']),
            'description' => trim((string) $validated['description']),
            'status' => $validated['status'] ?? 'available',
            'focus' => trim((string) $validated['focus']),
            'stage_label' => $this->nullableTrim($validated['stage_label'] ?? null),
            'usage_window' => $this->nullableTrim($validated['usage_window'] ?? null),
            'best_for' => $this->nullableTrim($validated['best_for'] ?? null),
            'difficulty' => $this->nullableTrim($validated['difficulty'] ?? null),
            'key_benefits_json' => $this->parseTextareaLines($validated['key_benefits_text'] ?? null),
            'usage_flow_json' => $this->parseTextareaLines($validated['usage_flow_text'] ?? null),
            'safety_notes_json' => $this->parseTextareaLines($validated['safety_notes_text'] ?? null),
            'suggested_moves_json' => $this->parseTextareaLines($validated['suggested_moves_text'] ?? null),
            'is_active' => (bool) ($validated['is_active'] ?? false),
        ];
    }

    private function parseTextareaLines(?string $value): array
    {
        if ($value === null) {
            return [];
        }

        return collect(preg_split('/\r\n|\r|\n/', $value) ?: [])
            ->map(fn ($line) => trim((string) $line))
            ->filter()
            ->values()
            ->all();
    }

    private function nullableTrim(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalizeMovements(Request $request): void
    {
        $movements = collect($request->input('movements', []))
            ->filter(fn ($movement) => is_array($movement))
            ->map(fn ($movement) => [
                'movement_name' => trim((string) ($movement['movement_name'] ?? '')),
                'target_area' => trim((string) ($movement['target_area'] ?? '')),
            ])
            ->reject(fn ($movement) => $movement['movement_name'] === '' && $movement['target_area'] === '')
            ->values()
            ->all();

        $request->merge(['movements' => $movements]);
    }

    private function syncMovements(Equipment $equipment, array $movements): void
    {
        $equipment->movements()->delete();
        $equipment->movements()->createMany(
            collect($movements)
                ->values()
                ->map(fn ($movement, $index) => [
                    'movement_name' => trim((string) $movement['movement_name']),
                    'target_area' => trim((string) $movement['target_area']),
                    'sort_order' => $index + 1,
                ])
                ->all()
        );
    }

    private function taxonomyOptions(): array
    {
        return [
            'equipmentCategories' => EquipmentTaxonomy::CATEGORIES,
            'equipmentDifficulties' => EquipmentTaxonomy::DIFFICULTIES,
            'equipmentOtherValue' => EquipmentTaxonomy::OTHER,
        ];
    }

    /**
     * Kode alat unik berikutnya, format EQ-001 (increment dari kode terbesar).
     */
    private function generateEquipmentCode(): string
    {
        $maxNumber = Equipment::query()
            ->whereNotNull('code')
            ->get(['code'])
            ->map(fn ($eq) => (int) preg_replace('/\D/', '', (string) $eq->code))
            ->max() ?? 0;

        return 'EQ-'.str_pad((string) ($maxNumber + 1), 3, '0', STR_PAD_LEFT);
    }
}
