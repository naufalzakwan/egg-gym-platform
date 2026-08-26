<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTrainerSessionProgressRequest extends FormRequest
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
            'exercise_id' => ['required', 'integer', 'exists:training_program_session_exercises,id'],
            'completed_sets' => ['required', 'integer', 'min:0'],
            'status' => ['nullable', 'in:active,paused,completed'],
            'trainer_note' => ['nullable', 'string'],
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
            'exercise_id.required' => 'Exercise wajib dipilih.',
            'exercise_id.exists' => 'Exercise tidak ditemukan.',
            'completed_sets.required' => 'Jumlah set yang selesai wajib diisi.',
            'completed_sets.integer' => 'Jumlah set yang selesai harus berupa angka.',
            'status.in' => 'Status progres harus active, paused, atau completed.',
        ];
    }
}
