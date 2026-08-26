<?php

namespace App\Http\Requests\Api\V1\Member;

use Illuminate\Foundation\Http\FormRequest;

class StoreBookingRequest extends FormRequest
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
            'trainer_profile_id' => ['required', 'exists:trainer_profiles,id'],
            'session_title' => ['required', 'string', 'max:255'],
            'location' => ['required', 'string', 'max:255'],
            'session_count' => ['required', 'integer', 'min:1', 'max:30'],
            'reservations' => ['required', 'array', 'min:1', 'max:30'],
            'reservations.*.session_date' => ['required', 'date'],
            'reservations.*.start_time' => ['required', 'date_format:H:i:s'],
            'reservations.*.end_time' => ['required', 'date_format:H:i:s'],
            'member_note' => ['nullable', 'string'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            foreach ((array) $this->input('reservations', []) as $index => $reservation) {
                $start = $reservation['start_time'] ?? null;
                $end = $reservation['end_time'] ?? null;
                if (is_string($start) && is_string($end) && $end <= $start) {
                    $validator->errors()->add(
                        "reservations.{$index}.end_time",
                        'Jam selesai setiap sesi harus setelah jam mulai.'
                    );
                }
            }
        });
    }

    /**
     * Get custom validation messages.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'trainer_profile_id.required' => 'Trainer wajib dipilih.',
            'trainer_profile_id.exists' => 'Trainer tidak ditemukan.',
            'session_title.required' => 'Judul sesi wajib diisi.',
            'reservations.required' => 'Jadwal setiap sesi wajib dipilih.',
            'reservations.*.session_date.required' => 'Tanggal setiap sesi wajib dipilih.',
            'reservations.*.start_time.required' => 'Jam mulai setiap sesi wajib dipilih.',
            'reservations.*.end_time.required' => 'Jam selesai setiap sesi wajib dipilih.',
            'location.required' => 'Lokasi sesi wajib diisi.',
        ];
    }
}
