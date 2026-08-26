<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Member\UpdateMemberProfileRequest;
use App\Http\Resources\Api\V1\Member\MemberProfileResource;
use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Services\Member\MemberMonthlyWorkoutService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class MemberProfileController extends Controller
{
    public function __construct(
        private readonly MemberMonthlyWorkoutService $monthlyWorkouts,
    ) {}

    /**
     * Display the authenticated member profile.
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user()->load('memberProfile');

        $activeMembership = MemberMembership::query()
            ->with('membershipPlan')
            ->whereHas('memberProfile', function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->currentlyActive()
            ->latest('end_date')
            ->first();

        $user->setRelation('active_membership', $activeMembership);
        $user->setAttribute(
            'workouts_this_month',
            $user->memberProfile
                ? $this->monthlyWorkouts->countForMember((int) $user->memberProfile->id)
                : 0
        );

        return response()->json([
            'success' => true,
            'message' => 'Profil member berhasil diambil.',
            'data' => new MemberProfileResource($user),
            'meta' => null,
        ]);
    }

    /**
     * Update the authenticated member profile.
     */
    public function update(UpdateMemberProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->offsetUnset('workouts_this_month');
        $validated = $request->validated();

        // Ubah password (opsional): current_password harus cocok dengan yang tersimpan.
        if (! empty($validated['new_password'])) {
            if (! Hash::check($validated['current_password'], $user->password)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Password lama tidak sesuai.',
                ], 422);
            }
        }

        $userUpdates = [
            'name' => $validated['name'],
            'phone' => $validated['phone'],
        ];

        // Email opsional; hanya update bila dikirim (validasi unique sudah di request).
        if (! empty($validated['email'])) {
            $userUpdates['email'] = $validated['email'];
        }

        // Password baru; cast 'hashed' di model User otomatis meng-hash nilai ini,
        // sehingga kredensial baru langsung berlaku untuk login berikutnya.
        if (! empty($validated['new_password'])) {
            $userUpdates['password'] = $validated['new_password'];
        }

        $user->update($userUpdates);

        $memberProfile = $user->memberProfile ?: new MemberProfile([
            'user_id' => $user->id,
            'member_code' => 'MEM-'.str_pad((string) $user->id, 4, '0', STR_PAD_LEFT),
            'joined_at' => now(),
        ]);

        $memberProfile->fill([
            'gender' => $validated['gender'] ?? null,
            'birth_date' => $validated['birth_date'] ?? null,
            'height_cm' => $validated['height_cm'] ?? null,
            'weight_kg' => $validated['weight_kg'] ?? null,
            'fitness_goal' => $validated['fitness_goal'] ?? null,
            'medical_note' => $validated['medical_note'] ?? null,
        ]);

        $memberProfile->user()->associate($user);
        $memberProfile->save();

        $activeMembership = $user->memberProfile
            ?->memberships()
            ->with('membershipPlan')
            ->currentlyActive()
            ->latest('end_date')
            ->first();

        $user->load('memberProfile');
        $user->setRelation('active_membership', $activeMembership);
        $user->setAttribute(
            'workouts_this_month',
            $this->monthlyWorkouts->countForMember((int) $user->memberProfile->id)
        );

        return response()->json([
            'success' => true,
            'message' => 'Profil member berhasil diperbarui.',
            'data' => new MemberProfileResource($user),
            'meta' => null,
        ]);
    }
}
