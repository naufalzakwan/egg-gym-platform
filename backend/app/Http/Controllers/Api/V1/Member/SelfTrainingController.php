<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Models\GymEquipmentMovement;
use App\Models\SelfTrainingExercise;
use App\Models\SelfTrainingProgram;
use App\Models\SelfTrainingSession;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SelfTrainingController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $programs = SelfTrainingProgram::query()
            ->with(['sessions.exercises'])
            ->where('member_profile_id', $memberProfile->id)
            ->where('status', 'active')
            ->latest()
            ->get()
            ->map(fn ($program) => $this->formatProgram($program));

        return response()->json([
            'success' => true,
            'message' => 'Daftar program latihan mandiri berhasil diambil.',
            'data' => $programs,
            'meta' => null,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'description' => ['nullable', 'string'],
        ]);

        $program = SelfTrainingProgram::create([
            'member_profile_id' => $memberProfile->id,
            'title' => trim($validated['title']),
            'description' => $validated['description'] ?? null,
            'status' => 'active',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Program latihan mandiri berhasil dibuat.',
            'data' => $this->formatProgram($program->load('sessions.exercises')),
            'meta' => null,
        ], 201);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $program = SelfTrainingProgram::query()
            ->with(['sessions.exercises'])
            ->where('id', $id)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Detail program berhasil diambil.',
            'data' => $this->formatProgram($program),
            'meta' => null,
        ]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $program = SelfTrainingProgram::query()
            ->where('id', $id)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan.',
            ], 404);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:150'],
            'description' => ['nullable', 'string'],
        ]);

        $program->update([
            'title' => trim($validated['title'] ?? $program->title),
            'description' => $validated['description'] ?? $program->description,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Program berhasil diperbarui.',
            'data' => $this->formatProgram($program->load('sessions.exercises')),
            'meta' => null,
        ]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $program = SelfTrainingProgram::query()
            ->where('id', $id)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan.',
            ], 404);
        }

        $program->delete();

        return response()->json([
            'success' => true,
            'message' => 'Program berhasil dihapus.',
            'data' => null,
            'meta' => null,
        ]);
    }

    public function storeSession(Request $request, int $programId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $program = SelfTrainingProgram::query()
            ->where('id', $programId)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $program) {
            return response()->json([
                'success' => false,
                'message' => 'Program tidak ditemukan.',
            ], 404);
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'focus' => ['nullable', 'string', 'max:150'],
            'duration_minutes' => ['nullable', 'integer', 'min:1'],
        ]);

        $maxOrder = SelfTrainingSession::query()
            ->where('self_training_program_id', $program->id)
            ->max('sequence_order') ?? 0;

        $session = SelfTrainingSession::create([
            'self_training_program_id' => $program->id,
            'sequence_order' => $maxOrder + 1,
            'title' => trim($validated['title']),
            'focus' => $validated['focus'] ?? null,
            'duration_minutes' => $validated['duration_minutes'] ?? null,
            'status' => 'active',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Sesi berhasil ditambahkan.',
            'data' => $this->formatSession($session->load('exercises')),
            'meta' => null,
        ], 201);
    }

    public function updateSession(Request $request, int $programId, int $sessionId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $session = SelfTrainingSession::query()
            ->where('id', $sessionId)
            ->where('self_training_program_id', $programId)
            ->whereHas('program', fn ($q) => $q->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $session) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan.',
            ], 404);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:150'],
            'focus' => ['nullable', 'string', 'max:150'],
            'duration_minutes' => ['nullable', 'integer', 'min:1'],
        ]);

        $session->update([
            'title' => trim($validated['title'] ?? $session->title),
            'focus' => $validated['focus'] ?? $session->focus,
            'duration_minutes' => $validated['duration_minutes'] ?? $session->duration_minutes,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Sesi berhasil diperbarui.',
            'data' => $this->formatSession($session->load('exercises')),
            'meta' => null,
        ]);
    }

    public function destroySession(Request $request, int $programId, int $sessionId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $session = SelfTrainingSession::query()
            ->where('id', $sessionId)
            ->where('self_training_program_id', $programId)
            ->whereHas('program', fn ($q) => $q->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $session) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan.',
            ], 404);
        }

        $session->delete();

        return response()->json([
            'success' => true,
            'message' => 'Sesi berhasil dihapus.',
            'data' => null,
            'meta' => null,
        ]);
    }

    public function storeExercise(Request $request, int $programId, int $sessionId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $session = SelfTrainingSession::query()
            ->where('id', $sessionId)
            ->where('self_training_program_id', $programId)
            ->whereHas('program', fn ($q) => $q->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $session) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak ditemukan.',
            ], 404);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:150'],
            'target_muscle' => ['nullable', 'string', 'max:100'],
            'sets' => ['required', 'integer', 'min:1'],
            'reps' => ['required', 'integer', 'min:1'],
            'rest_seconds' => ['nullable', 'integer', 'min:0'],
            'load' => ['nullable', 'string', 'max:50'],
            'notes' => ['nullable', 'string'],
            'equipment_id' => ['nullable', 'integer', 'exists:equipments,id'],
            'gym_equipment_movement_id' => ['nullable', 'integer', 'exists:gym_equipment_movements,id', 'required_with:equipment_id'],
        ]);
        $source = $this->validatedEquipmentSource($validated);

        $maxOrder = SelfTrainingExercise::query()
            ->where('self_training_session_id', $session->id)
            ->max('sequence_order') ?? 0;

        $exercise = SelfTrainingExercise::create([
            'self_training_session_id' => $session->id,
            'equipment_id' => $source['equipment_id'],
            'gym_equipment_movement_id' => $source['gym_equipment_movement_id'],
            'equipment_name' => $source['equipment_name'],
            'sequence_order' => $maxOrder + 1,
            'name' => $source['movement_name'] ?? trim($validated['name']),
            'target_muscle' => $source['target_area'] ?? ($validated['target_muscle'] ?? null),
            'sets' => $validated['sets'],
            'reps' => $validated['reps'],
            'rest_seconds' => $validated['rest_seconds'] ?? null,
            'load' => $validated['load'] ?? null,
            'notes' => $validated['notes'] ?? null,
            'is_completed' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Latihan berhasil ditambahkan.',
            'data' => $this->formatExercise($exercise),
            'meta' => null,
        ], 201);
    }

    public function updateExercise(Request $request, int $programId, int $sessionId, int $exerciseId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $exercise = SelfTrainingExercise::query()
            ->where('id', $exerciseId)
            ->where('self_training_session_id', $sessionId)
            ->whereHas('session.program', fn ($q) => $q
                ->where('id', $programId)
                ->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $exercise) {
            return response()->json([
                'success' => false,
                'message' => 'Latihan tidak ditemukan.',
            ], 404);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'target_muscle' => ['nullable', 'string', 'max:100'],
            'sets' => ['sometimes', 'required', 'integer', 'min:1'],
            'reps' => ['sometimes', 'required', 'integer', 'min:1'],
            'rest_seconds' => ['nullable', 'integer', 'min:0'],
            'load' => ['nullable', 'string', 'max:50'],
            'notes' => ['nullable', 'string'],
            'equipment_id' => ['nullable', 'integer', 'exists:equipments,id'],
            'gym_equipment_movement_id' => ['nullable', 'integer', 'exists:gym_equipment_movements,id', 'required_with:equipment_id'],
        ]);
        $source = array_key_exists('equipment_id', $validated)
            || array_key_exists('gym_equipment_movement_id', $validated)
                ? $this->validatedEquipmentSource($validated)
                : null;

        $exercise->update([
            'name' => $source['movement_name'] ?? trim($validated['name'] ?? $exercise->name),
            'target_muscle' => $source['target_area'] ?? ($validated['target_muscle'] ?? $exercise->target_muscle),
            'sets' => $validated['sets'] ?? $exercise->sets,
            'reps' => $validated['reps'] ?? $exercise->reps,
            'rest_seconds' => $validated['rest_seconds'] ?? $exercise->rest_seconds,
            'load' => $validated['load'] ?? $exercise->load,
            'notes' => $validated['notes'] ?? $exercise->notes,
            'equipment_id' => $source['equipment_id'] ?? $exercise->equipment_id,
            'gym_equipment_movement_id' => $source['gym_equipment_movement_id'] ?? $exercise->gym_equipment_movement_id,
            'equipment_name' => $source['equipment_name'] ?? $exercise->equipment_name,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Latihan berhasil diperbarui.',
            'data' => $this->formatExercise($exercise),
            'meta' => null,
        ]);
    }

    public function toggleExercise(Request $request, int $programId, int $sessionId, int $exerciseId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $exercise = SelfTrainingExercise::query()
            ->where('id', $exerciseId)
            ->where('self_training_session_id', $sessionId)
            ->whereHas('session.program', fn ($q) => $q
                ->where('id', $programId)
                ->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $exercise) {
            return response()->json([
                'success' => false,
                'message' => 'Latihan tidak ditemukan.',
            ], 404);
        }

        $newStatus = ! $exercise->is_completed;
        $exercise->update([
            'is_completed' => $newStatus,
            'completed_at' => $newStatus ? now() : null,
        ]);

        return response()->json([
            'success' => true,
            'message' => $newStatus ? 'Latihan ditandai selesai.' : 'Latihan dibatalkan selesai.',
            'data' => $this->formatExercise($exercise),
            'meta' => null,
        ]);
    }

    public function destroyExercise(Request $request, int $programId, int $sessionId, int $exerciseId): JsonResponse
    {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        $exercise = SelfTrainingExercise::query()
            ->where('id', $exerciseId)
            ->where('self_training_session_id', $sessionId)
            ->whereHas('session.program', fn ($q) => $q
                ->where('id', $programId)
                ->where('member_profile_id', $memberProfile->id))
            ->first();

        if (! $exercise) {
            return response()->json([
                'success' => false,
                'message' => 'Latihan tidak ditemukan.',
            ], 404);
        }

        $exercise->delete();

        return response()->json([
            'success' => true,
            'message' => 'Latihan berhasil dihapus.',
            'data' => null,
            'meta' => null,
        ]);
    }

    private function formatProgram(SelfTrainingProgram $program): array
    {
        $sessions = $program->sessions ?? collect();
        $totalExercises = $sessions->sum(fn ($s) => $s->exercises->count());
        $completedExercises = $sessions->sum(
            fn ($s) => $s->exercises->where('is_completed', true)->count()
        );

        return [
            'id' => $program->id,
            'title' => $program->title,
            'description' => $program->description,
            'status' => $program->status,
            'total_sessions' => $sessions->count(),
            'total_exercises' => $totalExercises,
            'completed_exercises' => $completedExercises,
            'progress_percent' => $totalExercises > 0
                ? round(($completedExercises / $totalExercises) * 100)
                : 0,
            'sessions' => $sessions->map(fn ($s) => $this->formatSession($s))->values(),
        ];
    }

    private function formatSession(SelfTrainingSession $session): array
    {
        $exercises = $session->exercises ?? collect();

        return [
            'id' => $session->id,
            'sequence_order' => $session->sequence_order,
            'title' => $session->title,
            'focus' => $session->focus,
            'duration_minutes' => $session->duration_minutes,
            'status' => $session->status,
            'total_exercises' => $exercises->count(),
            'completed_exercises' => $exercises->where('is_completed', true)->count(),
            'exercises' => $exercises->map(fn ($e) => $this->formatExercise($e))->values(),
        ];
    }

    private function formatExercise(SelfTrainingExercise $exercise): array
    {
        return [
            'id' => $exercise->id,
            'sequence_order' => $exercise->sequence_order,
            'name' => $exercise->name,
            'target_muscle' => $exercise->target_muscle,
            'sets' => $exercise->sets,
            'reps' => $exercise->reps,
            'rest_seconds' => $exercise->rest_seconds,
            'load' => $exercise->load,
            'notes' => $exercise->notes,
            'equipment_id' => $exercise->equipment_id,
            'equipment_name' => $exercise->equipment_name,
            'gym_equipment_movement_id' => $exercise->gym_equipment_movement_id,
            'source' => $exercise->gym_equipment_movement_id ? 'equipment_database' : 'manual',
            'is_completed' => $exercise->is_completed,
            'completed_at' => $exercise->completed_at?->toIso8601String(),
        ];
    }

    private function validatedEquipmentSource(array $validated): array
    {
        $equipmentId = $validated['equipment_id'] ?? null;
        $movementId = $validated['gym_equipment_movement_id'] ?? null;
        if ($equipmentId === null && $movementId === null) {
            return [
                'equipment_id' => null,
                'gym_equipment_movement_id' => null,
                'equipment_name' => null,
                'movement_name' => null,
                'target_area' => null,
            ];
        }

        abort_if($equipmentId === null || $movementId === null, 422, 'Alat dan gerakan wajib dipilih bersama.');
        $movement = GymEquipmentMovement::query()
            ->with('equipment:id,name')
            ->whereKey($movementId)
            ->where('gym_equipment_id', $equipmentId)
            ->first();
        abort_if($movement === null, 422, 'Gerakan tidak tersedia pada alat gym yang dipilih.');

        return [
            'equipment_id' => $movement->gym_equipment_id,
            'gym_equipment_movement_id' => $movement->id,
            'equipment_name' => $movement->equipment->name,
            'movement_name' => $movement->movement_name,
            'target_area' => $movement->target_area,
        ];
    }
}
