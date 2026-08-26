<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateTrainerScheduleDateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'mode' => ['required', 'string', Rule::in(['override', 'closed'])],
            'lock_version' => ['required', 'integer', 'min:1'],
            // `present` mengizinkan [] untuk mode closed; service memastikan
            // override minimal satu shift dan closed tidak punya shift.
            'shifts' => ['present', 'array'],
            'shifts.*' => ['required', 'array:start_time,end_time'],
            'shifts.*.start_time' => ['required', 'date_format:H:i'],
            'shifts.*.end_time' => ['required', 'date_format:H:i'],
        ];
    }
}
