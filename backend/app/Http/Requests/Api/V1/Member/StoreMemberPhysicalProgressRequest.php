<?php

namespace App\Http\Requests\Api\V1\Member;

use Illuminate\Foundation\Http\FormRequest;

class StoreMemberPhysicalProgressRequest extends FormRequest
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
            'weight_kg' => ['required', 'numeric', 'min:1'],
            'height_cm' => ['required', 'numeric', 'min:1'],
            'recorded_at' => ['required', 'date'],
            'note' => ['nullable', 'string'],
            'is_milestone' => ['nullable', 'boolean'],
            'photos' => ['nullable', 'array'],
            'photos.*' => ['nullable', 'image', 'max:4096'],
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
            'weight_kg.required' => 'Berat badan wajib diisi.',
            'height_cm.required' => 'Tinggi badan wajib diisi.',
            'recorded_at.required' => 'Tanggal checkpoint wajib diisi.',
            'photos.*.image' => 'File foto harus berupa gambar.',
            'photos.*.max' => 'Ukuran foto maksimal 4MB.',
        ];
    }
}
