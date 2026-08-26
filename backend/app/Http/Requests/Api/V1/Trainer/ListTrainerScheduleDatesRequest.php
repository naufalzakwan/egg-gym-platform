<?php

namespace App\Http\Requests\Api\V1\Trainer;

use Illuminate\Foundation\Http\FormRequest;

class ListTrainerScheduleDatesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'month' => ['nullable', 'string', 'regex:/^\d{4}-(0[1-9]|1[0-2])$/'],
        ];
    }
}
