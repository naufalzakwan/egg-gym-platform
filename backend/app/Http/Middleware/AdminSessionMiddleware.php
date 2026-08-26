<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class AdminSessionMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $adminUserId = $request->session()->get('admin_user_id');
        if (! $adminUserId) {
            return redirect()->route('admin.login');
        }

        $admin = User::query()->with('role')->find($adminUserId);
        if (! $admin || $admin->role?->name !== 'admin' || $admin->status !== 'active') {
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('admin.login')->withErrors([
                'email' => 'Sesi Admin tidak lagi aktif.',
            ]);
        }

        Auth::setUser($admin);
        $request->session()->put([
            'admin_user_name' => $admin->name,
            'admin_user_email' => $admin->email,
        ]);

        return $next($request);
    }
}
