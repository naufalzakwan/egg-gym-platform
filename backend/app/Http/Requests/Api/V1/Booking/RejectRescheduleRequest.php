<?php

namespace App\Http\Requests\Api\V1\Booking;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RejectRescheduleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'rejected_reason_type' => ['required', 'string', Rule::in([
                'new_schedule_not_suitable', 'other_activity', 'too_close',
                'keep_original_schedule', 'schedule_conflict',
                'outside_active_schedule', 'operational_issue', 'other',
            ])],
            'rejected_reason_note' => [
                'nullable', 'string', 'max:500',
                'required_if:rejected_reason_type,other',
            ],
        ];
    }
}
