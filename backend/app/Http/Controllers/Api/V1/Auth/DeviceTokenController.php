<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\StoreDeviceTokenRequest;
use App\Models\UserDeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * Store or update the authenticated user device token.
     */
    public function store(StoreDeviceTokenRequest $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validated();

        // Satu token FCM hanya boleh aktif untuk akun yang saat ini login pada
        // perangkat tersebut agar push tidak terkirim ke akun sebelumnya.
        UserDeviceToken::query()
            ->where('fcm_token', $validated['fcm_token'])
            ->where('user_id', '!=', $user->id)
            ->update(['is_active' => false]);

        $deviceToken = UserDeviceToken::updateOrCreate(
            [
                'user_id' => $user->id,
                'device_id' => $validated['device_id'],
            ],
            [
                'fcm_token' => $validated['fcm_token'],
                'platform' => $validated['platform'] ?? null,
                'device_name' => $validated['device_name'] ?? null,
                'is_active' => true,
                'last_seen_at' => now(),
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Device token berhasil disimpan.',
            'data' => [
                'id' => $deviceToken->id,
                'device_id' => $deviceToken->device_id,
                'platform' => $deviceToken->platform,
                'device_name' => $deviceToken->device_name,
                'is_active' => $deviceToken->is_active,
                'last_seen_at' => $deviceToken->last_seen_at?->toIso8601String(),
            ],
            'meta' => null,
        ]);
    }

    /**
     * Deactivate the authenticated user device token.
     */
    public function destroy(Request $request): JsonResponse
    {
        $deviceId = $request->input('device_id');

        if (! $deviceId) {
            return response()->json([
                'success' => false,
                'message' => 'Device ID wajib diisi.',
                'errors' => [
                    'device_id' => ['Device ID wajib diisi.'],
                ],
            ], 422);
        }

        $deviceToken = UserDeviceToken::query()
            ->where('user_id', $request->user()->id)
            ->where('device_id', $deviceId)
            ->first();

        if (! $deviceToken) {
            return response()->json([
                'success' => false,
                'message' => 'Device token tidak ditemukan.',
            ], 404);
        }

        $deviceToken->update([
            'is_active' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Device token berhasil dinonaktifkan.',
            'data' => null,
            'meta' => null,
        ]);
    }
}
