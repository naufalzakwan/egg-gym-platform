<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;

class StoreTrainingProgramRequest extends FormRequest
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
            'member_profile_id' => ['required', 'exists:member_profiles,id'],
            'booking_id' => ['nullable', 'exists:bookings,id'],
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'goal' => ['nullable', 'string', 'max:150'],
            'status' => ['nullable', 'in:draft,published,active,archived'],
            'started_at' => ['nullable', 'date'],
            'ended_at' => ['nullable', 'date', 'after_or_equal:started_at'],
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
            'member_profile_id.required' => 'Klien wajib dipilih.',
            'member_profile_id.exists' => 'Klien tidak ditemukan.',
            'booking_id.exists' => 'Booking tidak ditemukan.',
            'title.required' => 'Nama program wajib diisi.',
            'status.in' => 'Status program harus draft, published, active, atau archived.',
            'ended_at.after_or_equal' => 'Tanggal selesai tidak boleh sebelum tanggal mulai.',
        ];
    }
}
