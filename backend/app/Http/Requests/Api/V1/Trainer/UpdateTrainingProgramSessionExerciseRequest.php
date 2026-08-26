<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTrainingProgramSessionExerciseRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'exercise_library_id' => ['nullable', 'integer'],
            'equipment_id' => ['nullable', 'integer', 'exists:equipments,id', 'required_with:gym_equipment_movement_id'],
            'gym_equipment_movement_id' => ['nullable', 'integer', 'exists:gym_equipment_movements,id', 'required_with:equipment_id'],
            'equipment_name' => ['nullable', 'string', 'max:255'],
            'sequence_order' => ['required', 'integer', 'min:1'],
            'custom_name' => ['required_without:exercise_library_id', 'nullable', 'string', 'max:150'],
            'custom_target_muscle' => ['required_without:exercise_library_id', 'nullable', 'string', 'max:100'],
            'sets' => ['required', 'integer', 'min:1'],
            'reps' => ['required', 'integer', 'min:1'],
            'rest_seconds' => ['nullable', 'integer', 'min:0'],
            'cue_text' => ['nullable', 'string'],
            'status' => ['nullable', 'in:locked,active,completed'],
        ];
    }

    /**
     * Get custom validation messages.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'sequence_order.required' => 'Urutan latihan wajib diisi.',
            'custom_name.required_without' => 'Nama latihan wajib diisi jika belum memilih dari database.',
            'custom_target_muscle.required_without' => 'Target otot wajib diisi jika belum memilih dari database.',
            'sets.required' => 'Jumlah set wajib diisi.',
            'reps.required' => 'Jumlah reps wajib diisi.',
            'status.in' => 'Status latihan harus locked, active, atau completed.',
        ];
    }
}
