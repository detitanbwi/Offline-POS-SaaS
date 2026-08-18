<?php

namespace App\Services;

use App\Enums\DeviceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\Device;
use App\Models\LicenseToken;
use App\Repositories\DeviceRepository;
use App\Repositories\LicenseTokenRepository;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class LicenseService
{
    public function __construct(
        protected LicenseTokenRepository $tokenRepository,
        protected DeviceRepository $deviceRepository,
        protected AuditService $auditService,
    ) {}

    /**
     * Aktivasi token — bind ke device.
     *
     * Flow:
     * 1. Cari token berdasarkan token_key
     * 2. Validasi status token, subscription, tenant
     * 3. Cek apakah token sudah dipakai (1 token = 1 device)
     * 4. Bind device baru
     * 5. Generate offline activation token (JWT)
     */
    public function activateDevice(string $tokenKey, string $fingerprintHash, array $deviceInfo): array
    {
        $token = $this->tokenRepository->findByTokenKeyWithRelations($tokenKey);

        if (! $token) {
            return ['success' => false, 'message' => 'Token lisensi tidak ditemukan', 'code' => 404];
        }

        // Cek status token
        if ($token->status === TokenStatus::REVOKED) {
            return ['success' => false, 'message' => 'Token telah dicabut', 'code' => 403];
        }

        if ($token->status === TokenStatus::EXPIRED) {
            return ['success' => false, 'message' => 'Token telah kedaluwarsa', 'code' => 403];
        }

        // Cek tenant
        if ($token->tenant && $token->tenant->status->value !== 'active') {
            return ['success' => false, 'message' => 'Tenant dinonaktifkan', 'code' => 403];
        }

        // Cek subscription
        $subscription = $token->subscription;
        if (! $subscription || $subscription->status !== SubscriptionStatus::ACTIVE) {
            return ['success' => false, 'message' => 'Subscription tidak aktif', 'code' => 403];
        }

        // Cek expiry subscription
        if ($subscription->expiry_date->isPast()) {
            $subscription->update(['status' => SubscriptionStatus::EXPIRED]);
            $token->update(['status' => TokenStatus::EXPIRED]);

            return ['success' => false, 'message' => 'Subscription telah kedaluwarsa', 'code' => 403];
        }

        return DB::transaction(function () use ($token, $fingerprintHash, $deviceInfo, $subscription) {
            // Cek apakah token sedang aktif terikat ke device aktif
            $activeDevice = $token->activeDevice;

            if ($token->status === TokenStatus::ACTIVE && $activeDevice) {
                // Jika device yang sama → re-validasi
                if ($activeDevice->fingerprint_hash === $fingerprintHash) {
                    $activeDevice->update(['last_validated_at' => Carbon::now()]);
                    $token->update(['last_validated_at' => Carbon::now()]);

                    $offlineToken = $this->generateOfflineToken($token, $activeDevice);

                    return [
                        'success' => true,
                        'offline_token' => $offlineToken,
                        'expires_at' => $subscription->expiry_date->toIso8601String(),
                    ];
                }

                // Device berbeda → tolak (1 token = 1 device)
                return [
                    'success' => false,
                    'message' => 'Token sudah digunakan pada perangkat lain. Harap membeli lisensi lagi.',
                    'code' => 400,
                ];
            }

            // Token siap terikat (AVAILABLE) atau baru di-reset — cari jika device record sudah ada
            $device = Device::where('license_token_id', $token->id)
                ->where('fingerprint_hash', $fingerprintHash)
                ->first();

            if ($device) {
                // Reactivate existing device
                $device->update([
                    'status' => DeviceStatus::ACTIVE,
                    'android_id_hash' => $deviceInfo['android_id_hash'] ?? $device->android_id_hash,
                    'manufacturer' => $deviceInfo['manufacturer'] ?? $device->manufacturer,
                    'brand' => $deviceInfo['brand'] ?? $device->brand,
                    'model' => $deviceInfo['model'] ?? $device->model,
                    'installation_uuid_hash' => $deviceInfo['installation_uuid_hash'] ?? $device->installation_uuid_hash,
                    'activated_at' => Carbon::now(),
                    'last_validated_at' => Carbon::now(),
                ]);
            } else {
                // Bind device baru
                $device = Device::create([
                    'license_token_id' => $token->id,
                    'tenant_id' => $token->tenant_id,
                    'fingerprint_hash' => $fingerprintHash,
                    'android_id_hash' => $deviceInfo['android_id_hash'] ?? null,
                    'manufacturer' => $deviceInfo['manufacturer'] ?? null,
                    'brand' => $deviceInfo['brand'] ?? null,
                    'model' => $deviceInfo['model'] ?? null,
                    'installation_uuid_hash' => $deviceInfo['installation_uuid_hash'] ?? null,
                    'status' => DeviceStatus::ACTIVE,
                    'activated_at' => Carbon::now(),
                    'last_validated_at' => Carbon::now(),
                ]);
            }

            // Update token status ke ACTIVE
            $token->update([
                'status' => TokenStatus::ACTIVE,
                'activated_at' => Carbon::now(),
                'last_validated_at' => Carbon::now(),
            ]);

            $offlineToken = $this->generateOfflineToken($token, $device);

            $this->auditService->log(
                'device_activation',
                $token->tenant_id,
                $token->id,
                $device->id,
                "Token {$token->token_key} diaktifkan pada perangkat {$device->display_name}"
            );

            return [
                'success' => true,
                'offline_token' => $offlineToken,
                'expires_at' => $subscription->expiry_date->toIso8601String(),
            ];
        });
    }

    /**
     * Validasi token yang sudah aktif.
     */
    public function validateToken(string $tokenKey, string $fingerprintHash): array
    {
        $token = $this->tokenRepository->findByTokenKeyWithRelations($tokenKey);

        if (! $token) {
            return ['success' => false, 'message' => 'Token tidak ditemukan'];
        }

        if ($token->status === TokenStatus::REVOKED) {
            return ['success' => false, 'message' => 'Token dicabut'];
        }

        // Cek subscription expiry
        $subscription = $token->subscription;
        if (! $subscription || $subscription->expiry_date->isPast()) {
            if ($subscription) {
                $subscription->update(['status' => SubscriptionStatus::EXPIRED]);
            }
            $token->update(['status' => TokenStatus::EXPIRED]);

            return ['success' => false, 'message' => 'Subscription kedaluwarsa'];
        }

        // Pulihkan status token & subscription jika sebelumnya marked expired tetapi admin sudah perpanjang
        if ($subscription->status === SubscriptionStatus::EXPIRED) {
            $subscription->update(['status' => SubscriptionStatus::ACTIVE]);
        }
        if ($token->status === TokenStatus::EXPIRED) {
            $token->update(['status' => TokenStatus::ACTIVE]);
        }

        // Cek device
        $device = $token->activeDevice;
        if (! $device || $device->fingerprint_hash !== $fingerprintHash) {
            return ['success' => false, 'message' => 'Perangkat tidak terdaftar'];
        }

        if ($device->status !== DeviceStatus::ACTIVE) {
            return ['success' => false, 'message' => 'Perangkat dinonaktifkan'];
        }

        // Update validasi
        $device->update(['last_validated_at' => Carbon::now()]);
        $token->update(['last_validated_at' => Carbon::now()]);

        $offlineToken = $this->generateOfflineToken($token, $device);

        $this->auditService->log(
            'license_validation',
            $token->tenant_id,
            $token->id,
            $device->id
        );

        return [
            'success' => true,
            'offline_token' => $offlineToken,
            'expires_at' => $subscription->expiry_date->toIso8601String(),
        ];
    }

    /**
     * Reset device dari token — admin action.
     */
    public function resetDevice(string $tokenId): bool
    {
        return DB::transaction(function () use ($tokenId) {
            $token = $this->tokenRepository->findByIdOrFail($tokenId);
            $device = $token->device;

            if ($device) {
                $device->update(['status' => DeviceStatus::DEACTIVATED]);

                $this->auditService->log(
                    'device_reset',
                    $token->tenant_id,
                    $token->id,
                    $device->id,
                    "Device {$device->display_name} di-reset dari token {$token->token_key}"
                );
            }

            // Token kembali ke available agar bisa dipakai device lain
            $token->update(['status' => TokenStatus::AVAILABLE]);

            return true;
        });
    }

    /**
     * Revoke (cabut) token.
     */
    public function revokeToken(string $tokenId): bool
    {
        return DB::transaction(function () use ($tokenId) {
            $token = $this->tokenRepository->findByIdOrFail($tokenId);

            // Deactivate device jika ada
            if ($token->device && $token->device->status === DeviceStatus::ACTIVE) {
                $token->device->update(['status' => DeviceStatus::DEACTIVATED]);
            }

            $token->update(['status' => TokenStatus::REVOKED]);

            $this->auditService->log(
                'token_revoked',
                $token->tenant_id,
                $token->id,
                $token->device?->id,
                "Token {$token->token_key} dicabut"
            );

            return true;
        });
    }

    /**
     * Generate offline JWT token untuk Flutter client using RS256.
     */
    private function generateOfflineToken(LicenseToken $token, Device $device): string
    {
        $base64UrlEncode = function ($data) {
            return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($data));
        };

        $header = json_encode([
            'alg' => 'RS256',
            'typ' => 'JWT',
        ]);

        $subscription = $token->subscription;

        $payload = json_encode([
            'token_key' => $token->token_key,
            'fingerprint_hash' => $device->fingerprint_hash,
            'exp' => $subscription->expiry_date->timestamp,
            'tenant_id' => $token->tenant_id,
            'device_id' => $device->id,
            'iat' => now()->timestamp,
        ]);

        $base64UrlHeader = $base64UrlEncode($header);
        $base64UrlPayload = $base64UrlEncode($payload);

        $privateKeyPath = storage_path('license-private.key');
        if (!file_exists($privateKeyPath)) {
            throw new \RuntimeException('RSA Private Key not found. Please run php artisan license:keys');
        }

        $privateKey = file_get_contents($privateKeyPath);
        $dataToSign = $base64UrlHeader . '.' . $base64UrlPayload;

        if (!openssl_sign($dataToSign, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
            throw new \RuntimeException('Failed to sign JWT with RSA Private Key');
        }

        $base64UrlSignature = $base64UrlEncode($signature);

        return $base64UrlHeader . '.' . $base64UrlPayload . '.' . $base64UrlSignature;
    }
}
