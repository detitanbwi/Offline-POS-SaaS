<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        if (! $user || ! $user->hasPermission($permission)) {
            if ($request->expectsJson()) {
                return response()->json([
                    'message' => 'Akses Ditolak: Anda tidak memiliki wewenang untuk tindakan ini.',
                ], 403);
            }

            abort(403, 'Akses Ditolak: Anda tidak memiliki wewenang untuk tindakan ini.');
        }

        return $next($request);
    }
}
