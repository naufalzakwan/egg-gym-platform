<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user || ! $user->role) {
            return response()->json([
                'success' => false,
                'message' => 'Akses ditolak.',
                'errors' => [
                    'authorization' => ['User tidak memiliki role yang valid.'],
                ],
            ], 403);
        }

        if (! in_array($user->role->name, $roles, true)) {
            return response()->json([
                'success' => false,
                'message' => 'Role tidak diizinkan mengakses endpoint ini.',
                'errors' => [
                    'authorization' => ['Kamu tidak memiliki hak akses ke resource ini.'],
                ],
            ], 403);
        }

        return $next($request);
    }
}
