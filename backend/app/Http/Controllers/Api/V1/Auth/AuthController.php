<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\LoginRequest;
use App\Http\Requests\Api\V1\Auth\RegisterRequest;
use App\Models\MemberProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Handle registration request.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $validated = $request->validated();
        $memberRole = Role::query()->where('name', 'member')->first();

        if (! $memberRole) {
            return response()->json([
                'success' => false,
                'message' => 'Konfigurasi role member tidak ditemukan.',
            ], 500);
        }

        $user = DB::transaction(function () use ($validated, $memberRole) {
            $user = User::create([
                'role_id' => $memberRole->id,
                'name' => trim($validated['name']),
                'email' => trim($validated['email']),
                'password' => Hash::make($validated['password']),
                'phone' => trim($validated['phone']),
                'status' => 'active',
            ]);

            MemberProfile::create([
                'user_id' => $user->id,
                'member_code' => 'MBR-'.str_pad($user->id, 5, '0', STR_PAD_LEFT),
            ]);

            return $user;
        });

        $user->load('role');
        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Registrasi berhasil.',
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'role' => $user->role?->name,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'avatar_url' => $user->avatar_url,
                    'status' => $user->status,
                ],
            ],
        ], 201);
    }

    /**
     * Handle login request and issue Sanctum token.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::with('role')
            ->where('email', $request->input('email'))
            ->first();

        if (! $user || ! Hash::check($request->input('password'), $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Email atau password salah.',
                'errors' => [
                    'email' => ['Kredensial yang diberikan tidak valid.'],
                ],
            ], 401);
        }

        if ($user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Akun ini tidak aktif.',
                'errors' => [
                    'account' => ['Silakan hubungi admin untuk mengaktifkan akun.'],
                ],
            ], 403);
        }

        $user->update([
            'last_login_at' => now(),
        ]);

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'role' => $user->role?->name,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'avatar_url' => $user->avatar_url,
                    'status' => $user->status,
                ],
            ],
        ]);
    }

    /**
     * Return authenticated user profile.
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load('role');

        return response()->json([
            'success' => true,
            'message' => 'Profil user berhasil diambil.',
            'data' => [
                'id' => $user->id,
                'role' => $user->role?->name,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'avatar_url' => $user->avatar_url,
                'status' => $user->status,
                'last_login_at' => $user->last_login_at,
            ],
        ]);
    }

    /**
     * Revoke current access token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout berhasil.',
            'data' => null,
        ]);
    }
}
