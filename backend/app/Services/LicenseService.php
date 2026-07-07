<?php

namespace App\Services;

use App\Models\License;
use App\Models\Device;
use App\Models\Tenant;
use App\Models\Subscription;
use App\Models\SystemSetting;
use Illuminate\Support\Str;
use Carbon\Carbon;
use Illuminate\Support\Facades\Hash;

class LicenseService
{
    public function generateLicense(string $tenantId, string $plan, int $deviceLimit, ?int $expiresInDays = null)
    {
        $tenant = Tenant::findOrFail($tenantId);

        // Find or create subscription
        $startsAt = Carbon::now();
        $expiresAt = null;

        if ($plan === 'trial') {
            $trialDays = (int) SystemSetting::getVal('default_trial_days', 14);
            $expiresAt = Carbon::now()->addDays($trialDays);
        } elseif ($expiresInDays) {
            $expiresAt = Carbon::now()->addDays($expiresInDays);
        } elseif ($plan === 'monthly') {
            $expiresAt = Carbon::now()->addMonth();
        } elseif ($plan === 'yearly') {
            $expiresAt = Carbon::now()->addYear();
        } else {
            // Lifetime
            $expiresAt = Carbon::parse('2099-12-31 23:59:59');
        }

        $subscription = Subscription::create([
            'id' => (string) Str::uuid(),
            'tenant_id' => $tenant->id,
            'plan' => $plan,
            'status' => 'active',
            'starts_at' => $startsAt,
            'expires_at' => $expiresAt,
        ]);

        $licenseKey = 'LIC-' . strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4));
        $serverSecret = Str::random(32);

        $license = License::create([
            'tenant_id' => $tenant->id,
            'subscription_id' => $subscription->id,
            'license_key' => $licenseKey,
            'device_limit' => $deviceLimit,
            'device_count' => 0,
            'server_secret' => $serverSecret,
            'status' => 'AVAILABLE',
            'expires_at' => $expiresAt,
        ]);

        AuditService::log('license_generate', $tenant->id, $license->id, null, "License key: $licenseKey, Plan: $plan, Device Limit: $deviceLimit");

        return $license;
    }

    public function activateDevice(string $licenseKey, string $fingerprintHash, array $deviceInfo)
    {
        $license = License::where('license_key', $licenseKey)->first();

        if (!$license) {
            return ['success' => false, 'message' => 'Lisensi tidak ditemukan', 'code' => 404];
        }

        if ($license->status === 'REVOKED') {
            return ['success' => false, 'message' => 'Lisensi telah dicabut', 'code' => 403];
        }

        // Verify tenant status
        if ($license->tenant && $license->tenant->status !== 'active') {
            return ['success' => false, 'message' => 'Tenant dinonaktifkan', 'code' => 403];
        }

        // Check if subscription has expired
        if ($license->expires_at->isPast()) {
            $license->status = 'EXPIRED';
            $license->save();
            return ['success' => false, 'message' => 'Lisensi telah kedaluwarsa', 'code' => 403];
        }

        // Check if device already registered
        $device = Device::where('license_id', $license->id)
            ->where('fingerprint_hash', $fingerprintHash)
            ->first();

        if (!$device) {
            // Check device limit
            $activeCount = Device::where('license_id', $license->id)->where('status', 'active')->count();
            if ($activeCount >= $license->device_limit) {
                return ['success' => false, 'message' => 'Limit jumlah perangkat tercapai untuk lisensi ini', 'code' => 400];
            }

            // Bind new device
            $device = Device::create([
                'id' => (string) Str::uuid(),
                'license_id' => $license->id,
                'fingerprint_hash' => $fingerprintHash,
                'device_name' => $deviceInfo['device_name'] ?? 'Android Device',
                'device_model' => $deviceInfo['device_model'] ?? 'Model',
                'device_brand' => $deviceInfo['device_brand'] ?? 'Brand',
                'status' => 'active',
                'activated_at' => Carbon::now(),
                'last_validated_at' => Carbon::now(),
            ]);

            // Update license device count
            $license->device_count = Device::where('license_id', $license->id)->where('status', 'active')->count();
            $license->status = 'ACTIVE';
            if (!$license->activated_at) {
                $license->activated_at = Carbon::now();
            }
            $license->save();
        } else {
            // If device is already registered but was inactive, reactivate it
            if ($device->status !== 'active') {
                $device->status = 'active';
                $device->last_validated_at = Carbon::now();
                $device->save();
                
                $license->device_count = Device::where('license_id', $license->id)->where('status', 'active')->count();
                $license->save();
            } else {
                $device->last_validated_at = Carbon::now();
                $device->save();
            }
        }

        // Update license validation
        $license->last_validated_at = Carbon::now();
        $license->save();

        // Generate offline activation token
        $offlineToken = $this->generateOfflineToken($license, $device);

        AuditService::log('device_activation', $license->tenant_id, $license->id, $device->id, "Device: " . ($deviceInfo['device_name'] ?? ''));

        return [
            'success' => true,
            'offline_token' => $offlineToken,
            'server_secret' => $license->server_secret,
            'expires_at' => $license->expires_at->toIso8601String(),
        ];
    }

    public function validateLicense(string $licenseKey, string $fingerprintHash)
    {
        $license = License::where('license_key', $licenseKey)->first();

        if (!$license) {
            return ['success' => false, 'message' => 'Lisensi tidak ditemukan'];
        }

        if ($license->status === 'REVOKED') {
            return ['success' => false, 'message' => 'Lisensi dicabut'];
        }

        if ($license->expires_at->isPast()) {
            $license->status = 'EXPIRED';
            $license->save();
            return ['success' => false, 'message' => 'Lisensi kedaluwarsa'];
        }

        $device = Device::where('license_id', $license->id)
            ->where('fingerprint_hash', $fingerprintHash)
            ->where('status', 'active')
            ->first();

        if (!$device) {
            return ['success' => false, 'message' => 'Perangkat tidak terdaftar/dinonaktifkan'];
        }

        $device->last_validated_at = Carbon::now();
        $device->save();

        $license->last_validated_at = Carbon::now();
        $license->save();

        // Re-generate token with updated times
        $offlineToken = $this->generateOfflineToken($license, $device);

        AuditService::log('license_validation', $license->tenant_id, $license->id, $device->id);

        return [
            'success' => true,
            'offline_token' => $offlineToken,
            'expires_at' => $license->expires_at->toIso8601String(),
        ];
    }

    public function resetDevice(int $licenseId, string $deviceId)
    {
        $license = License::findOrFail($licenseId);
        $device = Device::where('license_id', $licenseId)->where('id', $deviceId)->firstOrFail();

        $device->status = 'deactivated';
        $device->save();

        $license->device_count = Device::where('license_id', $licenseId)->where('status', 'active')->count();
        if ($license->device_count === 0 && $license->status === 'ACTIVE') {
            $license->status = 'AVAILABLE';
        }
        $license->save();

        AuditService::log('device_reset', $license->tenant_id, $license->id, $device->id, "Reset device " . $device->device_name);

        return true;
    }

    private function generateOfflineToken(License $license, Device $device)
    {
        $base64UrlEncode = function ($data) {
            return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($data));
        };

        $header = json_encode([
            'alg' => 'HS256',
            'typ' => 'JWT'
        ]);

        $payload = json_encode([
            'license_key' => $license->license_key,
            'fingerprint_hash' => $device->fingerprint_hash,
            'exp' => $license->expires_at->timestamp,
            'tenant_id' => $license->tenant_id,
            'device_id' => $device->id,
        ]);

        $base64UrlHeader = $base64UrlEncode($header);
        $base64UrlPayload = $base64UrlEncode($payload);

        $secretKey = env('JWT_SECRET', 'SIMULATION_ONLY_NOT_FOR_PRODUCTION_SECRET_KEY_9921');

        $signature = hash_hmac('sha256', $base64UrlHeader . '.' . $base64UrlPayload, $secretKey, true);
        $base64UrlSignature = $base64UrlEncode($signature);

        return $base64UrlHeader . '.' . $base64UrlPayload . '.' . $base64UrlSignature;
    }
}
