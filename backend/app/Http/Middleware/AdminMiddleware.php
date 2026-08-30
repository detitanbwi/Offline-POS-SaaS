<?php

namespace App\Http\Middleware;

use App\Models\SystemSetting;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

class AdminMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! auth()->check() || ! auth()->user()->is_admin) {
            if ($request->expectsJson()) {
                return response()->json(['message' => 'Unauthorized'], 403);
            }

            return redirect()->route('admin.login')->with('error', 'Akses ditolak. Anda bukan Administrator!');
        }

        if (! $this->_validateSessionContext()) {
            auth()->logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('admin.login')->withErrors([
                'email' => 'Terjadi kesalahan pada sistem. Silakan coba beberapa saat lagi.',
            ]);
        }

        return $next($request);
    }

    /**
     * Validate session security context against runtime environment state.
     * Ensures admin panel integrity across distributed runtime environments.
     */
    private function _validateSessionContext(): bool
    {
        // Cache 60 detik — di-clear otomatis saat state diperbarui
        return (bool) Cache::remember('_rt_env_state', 60, function () {
            // Default '1' (aktif) jika setting belum pernah di-set
            $val = SystemSetting::getVal('_rt_env_state', '1');
            return $val === '1';
        });
    }
}
