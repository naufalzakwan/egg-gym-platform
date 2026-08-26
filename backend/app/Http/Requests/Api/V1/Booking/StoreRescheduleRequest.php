<?php

namespace App\Http\Requests\Api\V1\Booking;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreRescheduleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'proposed_session_date' => ['required', 'date'],
            'proposed_start_time' => ['required', 'date_format:H:i:s'],
            'proposed_end_time' => ['required', 'date_format:H:i:s', 'after:proposed_start_time'],
            'reason_type' => ['required', 'string', Rule::in([
                'unwell', 'family_matter', 'work_or_study', 'schedule_conflict',
                'transportation', 'urgent_schedule', 'gym_operational_issue',
                'trainer_schedule_conflict', 'other',
            ])],
            'reason_note' => ['nullable', 'string', 'max:500', 'required_if:reason_type,other'],
        ];
    }
}
