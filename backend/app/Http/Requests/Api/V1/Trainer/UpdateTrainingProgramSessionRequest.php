<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTrainingProgramSessionRequest extends FormRequest
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
            'sequence_order' => ['required', 'integer', 'min:1'],
            'title' => ['required', 'string', 'max:255'],
            'focus' => ['nullable', 'string', 'max:150'],
            'duration_minutes' => ['nullable', 'integer', 'min:1'],
            'status' => ['nullable', 'in:locked,active,completed,upcoming'],
            'unlock_rule' => ['nullable', 'string', 'max:50'],
            'coach_note' => ['nullable', 'string'],
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
            'sequence_order.required' => 'Urutan sesi wajib diisi.',
            'title.required' => 'Judul sesi wajib diisi.',
            'status.in' => 'Status sesi harus locked, active, completed, atau upcoming.',
        ];
    }
}
