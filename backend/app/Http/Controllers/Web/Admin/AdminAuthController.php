<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\ActivityLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\View\View;

class AdminAuthController extends Controller
{
    public function showLogin(): View|RedirectResponse
    {
        if (session('admin_user_id')) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.auth.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::query()
            ->with('role')
            ->where('email', $validated['email'])
            ->first();

        $isAdmin = $user?->role?->name === 'admin';

        if (! $user || ! $isAdmin || $user->status !== 'active' || ! Hash::check($validated['password'], $user->password)) {
            return back()
                ->withInput($request->only('email'))
                ->withErrors([
                    'email' => 'Email atau password admin tidak valid.',
                ]);
        }

        session([
            'admin_user_id' => $user->id,
            'admin_user_name' => $user->name,
            'admin_user_email' => $user->email,
        ]);

        $request->session()->regenerate();
        $user->forceFill(['last_login_at' => now()])->save();

        ActivityLogger::log(
            action: 'admin_login',
            model: $user,
            newData: [
                'admin_id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'source' => 'Web Admin',
                'status' => 'success',
            ],
            description: "Admin {$user->name} berhasil login ke Web Admin",
            userId: $user->id,
        );

        return redirect()->route('admin.dashboard');
    }

    public function logout(Request $request): RedirectResponse
    {
        $adminUserId = session('admin_user_id');
        $adminUserName = session('admin_user_name');
        $adminUserEmail = session('admin_user_email');

        if ($adminUserId) {
            ActivityLogger::log(
                action: 'admin_logout',
                model: User::query()->find($adminUserId),
                newData: [
                    'admin_id' => $adminUserId,
                    'name' => $adminUserName,
                    'email' => $adminUserEmail,
                    'source' => 'Web Admin',
                    'status' => 'success',
                ],
                description: "Admin {$adminUserName} logout dari Web Admin",
                userId: $adminUserId,
            );
        }

        $request->session()->forget([
            'admin_user_id',
            'admin_user_name',
            'admin_user_email',
        ]);

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
