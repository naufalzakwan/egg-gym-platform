<?php

namespace App\Http\Requests\Api\V1\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:100', 'regex:/^[A-Za-zÀ-ÿ\s]+$/u'],
            'email' => ['required', 'email', 'max:150', 'unique:users,email'],
            'password' => [
                'required',
                'string',
                Password::min(8)->mixedCase()->numbers()->symbols(),
                'confirmed',
            ],
            'phone' => ['required', 'string', 'regex:/^(08|628)[0-9]+$/', 'min:10', 'max:15'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Nama wajib diisi.',
            'name.regex' => 'Nama hanya boleh huruf dan spasi.',
            'email.required' => 'Email wajib diisi.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email sudah terdaftar.',
            'password.required' => 'Password wajib diisi.',
            'password.min' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'password.mixed' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'password.numbers' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'password.symbols' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'password.confirmed' => 'Konfirmasi password tidak sama.',
            'phone.required' => 'Nomor HP wajib diisi.',
            'phone.regex' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.min' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.max' => 'Nomor HP 10–15 digit, awali 08/628.',
        ];
    }
}
