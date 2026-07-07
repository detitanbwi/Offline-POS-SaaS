<?php

namespace App\Services;

use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditService
{
    public static function log(string $action, ?string $tenantId = null, ?int $licenseId = null, ?string $deviceId = null, ?string $details = null, ?Request $request = null)
    {
        $ip = $request ? $request->ip() : request()->ip();
        $ua = $request ? $request->userAgent() : request()->userAgent();
        $userId = auth()->check() ? auth()->id() : null;

        AuditLog::create([
            'tenant_id' => $tenantId,
            'license_id' => $licenseId,
            'device_id' => $deviceId,
            'user_id' => $userId,
            'action' => $action,
            'details' => $details,
            'ip_address' => $ip,
            'user_agent' => $ua,
        ]);
    }
}
