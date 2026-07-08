<?php

namespace App\Http\Controllers;

use App\Http\Requests\ActivateRequest;
use App\Http\Requests\ValidateLicenseRequest;
use App\Services\LicenseService;
use Illuminate\Http\JsonResponse;

class ActivationController extends Controller
{
    protected $licenseService;

    public function __construct(LicenseService $licenseService)
    {
        $this->licenseService = $licenseService;
    }

    public function activate(ActivateRequest $request): JsonResponse
    {
        $result = $this->licenseService->activateDevice(
            $request->license_key,
            $request->fingerprint_hash,
            $request->only(['device_name', 'device_model', 'device_brand'])
        );

        if (!$result['success']) {
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

    public function validateLicense(ValidateLicenseRequest $request): JsonResponse
    {
        $result = $this->licenseService->validateLicense(
            $request->license_key,
            $request->fingerprint_hash
        );

        if (!$result['success']) {
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
