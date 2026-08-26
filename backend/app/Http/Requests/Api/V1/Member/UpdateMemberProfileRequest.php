<?php

namespace App\Http\Requests\Api\V1\Member;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UpdateMemberProfileRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255', 'regex:/^[A-Za-zÀ-ÿ\s]+$/u'],
            // Email opsional (hanya dikirim dari form Identitas Akun). Cek
            // uniqueness ke tabel users, abaikan baris user yang sedang login.
            'email' => [
                'nullable',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($this->user()?->id),
            ],
            'phone' => ['required', 'string', 'regex:/^(08|628)[0-9]+$/', 'min:10', 'max:15'],
            'gender' => ['nullable', 'in:male,female'],
            'birth_date' => ['nullable', 'date'],
            'height_cm' => ['nullable', 'numeric', 'min:0'],
            'weight_kg' => ['nullable', 'numeric', 'min:0'],
            'fitness_goal' => ['nullable', 'string', 'max:255'],
            'medical_note' => ['nullable', 'string'],
            // Ubah password (opsional). Bila new_password diisi, current_password
            // wajib ada dan new_password harus dikonfirmasi (new_password_confirmation).
            'current_password' => ['nullable', 'required_with:new_password', 'string'],
            'new_password' => [
                'nullable',
                'string',
                Password::min(8)->mixedCase()->numbers()->symbols(),
                'confirmed',
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
            'name.required' => 'Nama wajib diisi.',
            'name.regex' => 'Nama hanya boleh huruf dan spasi.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email ini sudah digunakan oleh akun lain. Silakan pakai email berbeda.',
            'phone.required' => 'Nomor telepon wajib diisi.',
            'phone.regex' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.min' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.max' => 'Nomor HP 10–15 digit, awali 08/628.',
            'gender.in' => 'Gender harus bernilai male atau female.',
            'birth_date.date' => 'Tanggal lahir harus berupa tanggal yang valid.',
            'height_cm.numeric' => 'Tinggi badan harus berupa angka.',
            'weight_kg.numeric' => 'Berat badan harus berupa angka.',
            'current_password.required_with' => 'Password lama wajib diisi untuk mengubah password.',
            'new_password.min' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.mixed' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.numbers' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.symbols' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.confirmed' => 'Konfirmasi password tidak sama.',
        ];
    }
}
