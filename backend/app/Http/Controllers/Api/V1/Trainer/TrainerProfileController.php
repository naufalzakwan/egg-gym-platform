<?php

namespace App\Http\Controllers\Api\V1\Trainer;

use App\Http\Controllers\Controller;
use App\Support\TrainerSpecialty;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class TrainerProfileController extends Controller
{
    /**
     * Get trainer profile including payment info.
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user()->load([
            'trainerProfile' => fn ($query) => $query->withRatingStats(),
        ]);

        if (! $user->trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        $profile = $user->trainerProfile;

        return response()->json([
            'success' => true,
            'message' => 'Profil trainer berhasil diambil.',
            'data' => [
                'id' => $profile->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'specialty' => $profile->specialty,
                'specialty_label' => TrainerSpecialty::label($profile->specialty),
                'specialty_slug' => TrainerSpecialty::slug($profile->specialty),
                'specialties' => $profile->specialties ?? [$profile->specialty],
                'specialty_labels' => $profile->specialty_labels,
                'bio' => $profile->bio,
                'rating' => $profile->reviews_count > 0
                    ? round((float) $profile->rating_average, 2)
                    : 0.0,
                'reviews_count' => (int) $profile->reviews_count,
                'experience_years' => $profile->experience_years,
                'certifications' => $profile->certifications,
                'certifications_list' => $profile->certification_list,
                'availability_note' => $profile->availability_note,
                'display_photo_path' => $profile->display_photo_path,
                'tier' => $profile->tier_value,
                'tier_label' => $profile->tier_label,
                'status' => $user->status,
                'bank_name' => $profile->bank_name,
                'bank_account_number' => $profile->bank_account_number,
                'bank_account_name' => $profile->bank_account_name,
                'dana_number' => $profile->dana_number,
                'dana_account_name' => $profile->dana_account_name,
                'other_payment_method' => $profile->other_payment_method,
                'other_payment_number' => $profile->other_payment_number,
                'other_payment_account_name' => $profile->other_payment_account_name,
                'price_per_session' => $profile->price_per_session !== null
                    ? (float) $profile->price_per_session
                    : null,
            ],
            'meta' => null,
        ]);
    }

    /**
     * Update trainer profile including payment info.
     */
    public function update(Request $request): JsonResponse
    {
        $user = $request->user()->load('trainerProfile');

        if (! $user->trainerProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil trainer belum tersedia.',
            ], 422);
        }

        if (trim((string) $request->input('new_password', '')) === '') {
            $request->request->remove('current_password');
            $request->request->remove('new_password');
            $request->request->remove('new_password_confirmation');
        }
        if (is_string($request->input('certifications'))) {
            $request->merge([
                'certifications' => explode(',', (string) $request->input('certifications')),
            ]);
        }

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:100', 'regex:/^[A-Za-zÀ-ÿ\s]+$/u'],
            'email' => [
                'sometimes',
                'email',
                'max:150',
                Rule::unique('users', 'email')->ignore($user->id),
            ],
            'phone' => ['sometimes', 'string', 'regex:/^(08|628)[0-9]+$/', 'min:10', 'max:15'],
            'specialty' => [
                'sometimes',
                'string',
                'max:150',
                Rule::in(array_values(array_unique([
                    ...TrainerSpecialty::labels(),
                    (string) $user->trainerProfile->specialty,
                ]))),
            ],
            'specialties' => ['sometimes', 'array', 'min:1'],
            'specialties.*' => [
                'required',
                'string',
                'distinct',
                Rule::in(array_values(array_unique([
                    ...TrainerSpecialty::labels(),
                    (string) $user->trainerProfile->specialty,
                ]))),
            ],
            'bio' => ['nullable', 'string'],
            'experience_years' => ['nullable', 'integer', 'min:0'],
            'certifications' => ['nullable', 'array', 'max:20'],
            'certifications.*' => ['nullable', 'string', 'max:255'],
            'availability_note' => ['nullable', 'string'],
            'bank_name' => ['nullable', 'string', 'max:100'],
            'bank_account_number' => ['nullable', 'string', 'max:50'],
            'bank_account_name' => ['nullable', 'string', 'max:100'],
            'dana_number' => ['nullable', 'string', 'max:30'],
            'dana_account_name' => ['nullable', 'string', 'max:100'],
            'other_payment_method' => [
                'nullable',
                'required_with:other_payment_number,other_payment_account_name',
                'string',
                'max:50',
            ],
            'other_payment_number' => [
                'nullable',
                'required_with:other_payment_method,other_payment_account_name',
                'string',
                'max:100',
            ],
            'other_payment_account_name' => [
                'nullable',
                'required_with:other_payment_method,other_payment_number',
                'string',
                'max:100',
            ],
            'price_per_session' => ['nullable', 'numeric', 'min:0', 'max:100000000'],
            'current_password' => ['required_with:new_password', 'string'],
            'new_password' => [
                'nullable',
                'confirmed',
                Password::min(8)->mixedCase()->numbers()->symbols(),
            ],
        ], [
            'name.regex' => 'Nama hanya boleh huruf dan spasi.',
            'phone.regex' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.min' => 'Nomor HP 10–15 digit, awali 08/628.',
            'phone.max' => 'Nomor HP 10–15 digit, awali 08/628.',
            'new_password.min' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.mixed' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.numbers' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.symbols' => 'Password harus 8+ karakter, Aa, angka & simbol.',
            'new_password.confirmed' => 'Konfirmasi password tidak sama.',
        ]);

        if (! empty($validated['new_password'])
            && ! Hash::check((string) $validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Password lama tidak sesuai.'],
            ]);
        }

        DB::transaction(function () use ($user, $validated): void {
            $userUpdates = array_intersect_key($validated, array_flip([
                'name',
                'email',
                'phone',
            ]));
            if (! empty($validated['new_password'])) {
                $userUpdates['password'] = $validated['new_password'];
            }
            if ($userUpdates !== []) {
                $user->update($userUpdates);
            }

            $profileUpdates = array_intersect_key($validated, array_flip([
                'specialty',
                'specialties',
                'bio',
                'experience_years',
                'certifications',
                'availability_note',
                'bank_name',
                'bank_account_number',
                'bank_account_name',
                'dana_number',
                'dana_account_name',
                'other_payment_method',
                'other_payment_number',
                'other_payment_account_name',
                'price_per_session',
            ]));
            if (array_key_exists('specialties', $validated)) {
                $profileUpdates['specialties'] = array_values($validated['specialties']);
                $profileUpdates['specialty'] = $profileUpdates['specialties'][0];
            }
            if (array_key_exists('certifications', $validated)) {
                $profileUpdates['certifications'] = collect($validated['certifications'] ?? [])
                    ->map(fn ($value) => trim((string) $value))
                    ->filter()
                    ->unique(fn ($value) => mb_strtolower($value))
                    ->implode(', ');
                if ($profileUpdates['certifications'] === '') {
                    $profileUpdates['certifications'] = null;
                }
            }
            if ($profileUpdates !== []) {
                $user->trainerProfile->update($profileUpdates);
            }
        });

        $user->refresh()->load([
            'trainerProfile' => fn ($query) => $query->withRatingStats(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Profil trainer berhasil diperbarui.',
            'data' => [
                'id' => $user->trainerProfile->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'specialty' => $user->trainerProfile->specialty,
                'specialty_label' => TrainerSpecialty::label($user->trainerProfile->specialty),
                'specialty_slug' => TrainerSpecialty::slug($user->trainerProfile->specialty),
                'specialties' => $user->trainerProfile->specialties
                    ?? [$user->trainerProfile->specialty],
                'specialty_labels' => $user->trainerProfile->specialty_labels,
                'bio' => $user->trainerProfile->bio,
                'rating' => $user->trainerProfile->reviews_count > 0
                    ? round((float) $user->trainerProfile->rating_average, 2)
                    : 0.0,
                'reviews_count' => (int) $user->trainerProfile->reviews_count,
                'experience_years' => $user->trainerProfile->experience_years,
                'certifications' => $user->trainerProfile->certifications,
                'certifications_list' => $user->trainerProfile->certification_list,
                'availability_note' => $user->trainerProfile->availability_note,
                'display_photo_path' => $user->trainerProfile->display_photo_path,
                'tier' => $user->trainerProfile->tier_value,
                'tier_label' => $user->trainerProfile->tier_label,
                'status' => $user->status,
                'bank_name' => $user->trainerProfile->bank_name,
                'bank_account_number' => $user->trainerProfile->bank_account_number,
                'bank_account_name' => $user->trainerProfile->bank_account_name,
                'dana_number' => $user->trainerProfile->dana_number,
                'dana_account_name' => $user->trainerProfile->dana_account_name,
                'other_payment_method' => $user->trainerProfile->other_payment_method,
                'other_payment_number' => $user->trainerProfile->other_payment_number,
                'other_payment_account_name' => $user->trainerProfile->other_payment_account_name,
                'price_per_session' => $user->trainerProfile->price_per_session !== null
                    ? (float) $user->trainerProfile->price_per_session
                    : null,
            ],
            'meta' => null,
        ]);
    }
}
