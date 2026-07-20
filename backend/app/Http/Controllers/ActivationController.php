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

    public function getLicenseInfo(\Illuminate\Http\Request $request): JsonResponse
    {
        $user = $request->user();
        $tenant = $user->tenant;

        if (! $tenant) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant tidak ditemukan untuk akun ini',
            ], 404);
        }

        $subscription = $tenant->subscriptions()->where('status', \App\Enums\SubscriptionStatus::ACTIVE)->first();
        $tokens = $tenant->licenseTokens()->get();

        return response()->json([
            'success' => true,
            'tenant' => [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'owner_name' => $tenant->owner_name,
                'store_name' => $tenant->store_name,
                'store_address' => $tenant->store_address,
                'phone' => $tenant->phone,
                'status' => $tenant->status->value ?? $tenant->status,
            ],
            'subscription' => $subscription ? [
                'id' => $subscription->id,
                'package_name' => $subscription->package_name,
                'status' => $subscription->status->value ?? $subscription->status,
                'start_date' => $subscription->start_date?->toIso8601String(),
                'expiry_date' => $subscription->expiry_date?->toIso8601String(),
                'is_expired' => $subscription->expiry_date ? $subscription->expiry_date->isPast() : false,
            ] : null,
            'tokens' => $tokens->map(fn ($t) => [
                'token_key' => $t->token_key,
                'status' => $t->status->value ?? $t->status,
                'client_note' => $t->client_note,
                'activated_at' => $t->activated_at?->toIso8601String(),
            ]),
        ]);
    }
}
