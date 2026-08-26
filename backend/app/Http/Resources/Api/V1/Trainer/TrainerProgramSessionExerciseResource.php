<?php

namespace App\Http\Resources\Api\V1\Trainer;

use App\Models\TrainerSessionProgress;
use App\Models\TrainerSessionProgressExercise;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrainerProgramSessionExerciseResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // Cari progress untuk sesi ini
        $sessionProgress = TrainerSessionProgress::query()
            ->where('training_program_session_id', $this->training_program_session_id)
            ->first();

        // Cari progress exercise dari tabel trainer_session_progress_exercises
        $progressExercise = null;
        if ($sessionProgress) {
            $progressExercise = TrainerSessionProgressExercise::query()
                ->where('trainer_session_progress_id', $sessionProgress->id)
                ->where('training_program_session_exercise_id', $this->id)
                ->first();
        }

        return [
            'id' => $this->id,
            'training_program_session_id' => $this->training_program_session_id,
            'exercise_library_id' => $this->exercise_library_id,
            'equipment_id' => $this->equipment_id,
            'equipment_name' => $this->equipment_name,
            'gym_equipment_movement_id' => $this->gym_equipment_movement_id,
            'source' => $this->gym_equipment_movement_id ? 'equipment_database' : 'manual',
            'sequence_order' => $this->sequence_order,
            'custom_name' => $this->custom_name,
            'custom_target_muscle' => $this->custom_target_muscle,
            'sets' => $this->sets,
            'reps' => $this->reps,
            'rest_seconds' => $this->rest_seconds,
            'cue_text' => $this->cue_text,
            'status' => $progressExercise?->status ?? $this->status,
            'completed_sets' => $progressExercise?->completed_sets ?? 0,
            'total_sets' => $progressExercise?->total_sets ?? $this->sets,
        ];
    }
}
