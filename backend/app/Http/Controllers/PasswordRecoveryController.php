<?php

namespace App\Http\Controllers;

use App\Services\PasswordRecoveryService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PasswordRecoveryController extends Controller
{
    public function __construct(protected PasswordRecoveryService $passwordService) {}

    public function requestOtp(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        try {
            $result = $this->passwordService->requestOtp($request->email);
            return response()->json($result);
        } catch (Exception $e) {
            Log::error('Password Request OTP Error: ' . $e->getMessage());
            $status = $e->getCode() ?: 500;
            if ($status < 100 || $status > 599) $status = 500;
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $status);
        }
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|string|size:6',
        ]);

        try {
            $result = $this->passwordService->verifyOtp($request->email, $request->otp);
            return response()->json($result);
        } catch (Exception $e) {
            Log::error('Password Verify OTP Error: ' . $e->getMessage());
            $status = $e->getCode() ?: 500;
            if ($status < 100 || $status > 599) $status = 500;
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $status);
        }
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'reset_token' => 'required|string',
            'new_password' => 'required|string|min:6',
            'new_password_confirmation' => 'required|string|same:new_password',
        ]);

        try {
            $result = $this->passwordService->resetPassword(
                $request->email,
                $request->reset_token,
                $request->new_password
            );
            return response()->json($result);
        } catch (Exception $e) {
            Log::error('Password Reset Error: ' . $e->getMessage());
            $status = $e->getCode() ?: 500;
            if ($status < 100 || $status > 599) $status = 500;
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], $status);
        }
    }
}
