<?php

namespace App\Http\Requests\Api\V1\Member;

use Illuminate\Foundation\Http\FormRequest;

class RescheduleBookingRequest extends FormRequest
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
            'new_session_date' => ['required', 'date'],
            'new_start_time' => ['required', 'date_format:H:i:s'],
            'new_end_time' => ['required', 'date_format:H:i:s', 'after:new_start_time'],
            'reason' => ['required', 'string', 'max:500'],
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
            'new_session_date.required' => 'Tanggal baru wajib diisi.',
            'new_session_date.after_or_equal' => 'Tanggal baru tidak boleh sebelum hari ini.',
            'new_start_time.required' => 'Jam mulai baru wajib diisi.',
            'new_start_time.date_format' => 'Format jam mulai baru harus H:i:s.',
            'new_end_time.required' => 'Jam selesai baru wajib diisi.',
            'new_end_time.date_format' => 'Format jam selesai baru harus H:i:s.',
            'new_end_time.after' => 'Jam selesai baru harus setelah jam mulai baru.',
            'reason.required' => 'Alasan reschedule wajib diisi.',
        ];
    }
}
