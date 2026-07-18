<?php

namespace App\Http\Controllers;

use App\Http\Requests\ActivateTokenRequest;
use App\Http\Requests\ValidateTokenRequest;
use App\Services\LicenseService;
use Illuminate\Http\JsonResponse;

class ActivationController extends Controller
{
    public function __construct(
        protected LicenseService $licenseService,
    ) {}

    public function activate(ActivateTokenRequest $request): JsonResponse
    {
        $result = $this->licenseService->activateDevice(
            $request->token_key,
            $request->fingerprint_hash,
            $request->only([
                'android_id_hash',
                'manufacturer',
                'brand',
                'model',
                'installation_uuid_hash',
            ])
        );

        if (! $result['success']) {
            return response()->json([
                'success' => false,
                'message' => $result['message'],
            ], $result['code'] ?? 400);
        }

        return response()->json([
            'success' => true,
            'message' => 'Aktivasi berhasil!',
            'offline_token' => $result['offline_token'],
            'expires_at' => $result['expires_at'],
        ]);
    }

    public function validateLicense(ValidateTokenRequest $request): JsonResponse
    {
        $result = $this->licenseService->validateToken(
            $request->token_key,
            $request->fingerprint_hash
        );

        if (! $result['success']) {
            return response()->json([
                'success' => false,
                'message' => $result['message'],
            ], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Validasi berhasil!',
            'offline_token' => $result['offline_token'],
            'expires_at' => $result['expires_at'],
        ]);
    }
}
