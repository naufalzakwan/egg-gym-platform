<?php

namespace App\Http\Requests\Api\V1\Member;

use Illuminate\Foundation\Http\FormRequest;

class CheckoutMembershipPaymentRequest extends FormRequest
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
            'membership_plan_id' => ['required', 'exists:membership_plans,id'],
            'payment_method' => [
                'required',
                'string',
                'max:50',
            ],
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
            'membership_plan_id.required' => 'Paket membership wajib dipilih.',
            'membership_plan_id.exists' => 'Paket membership tidak ditemukan.',
            'payment_method.required' => 'Metode pembayaran wajib dipilih.',
        ];
    }
}
