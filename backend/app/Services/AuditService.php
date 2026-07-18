<?php

namespace App\Services;

use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditService
{
    /**
     * Catat audit log.
     */
    public function log(
        string $action,
        ?string $tenantId = null,
        ?string $licenseTokenId = null,
        ?string $deviceId = null,
        ?string $details = null,
        ?array $metadata = null,
        ?Request $request = null,
    ): AuditLog {
        $ip = $request ? $request->ip() : request()->ip();
        $ua = $request ? $request->userAgent() : request()->userAgent();
        $userId = auth()->check() ? auth()->id() : null;

        return AuditLog::create([
            'tenant_id' => $tenantId,
            'license_token_id' => $licenseTokenId,
            'device_id' => $deviceId,
            'user_id' => $userId,
            'action' => $action,
            'details' => $details,
            'metadata' => $metadata,
            'ip_address' => $ip,
            'user_agent' => $ua,
        ]);
    }
}
