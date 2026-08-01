<?php

namespace App\Http\Controllers;

use App\Services\PinRecoveryService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PinRecoveryController extends Controller
{
    public function __construct(protected PinRecoveryService $pinService) {}

    /**
     * POST /api/auth/request-otp
     */
    public function requestOtp(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        try {
            $result = $this->pinService->requestOtp($request->email);
            return response()->json($result, 200);
        } catch (Exception $e) {
            $status = $e->getCode() >= 400 && $e->getCode() <= 500 ? $e->getCode() : 400;
            return response()->json(['success' => false, 'message' => $e->getMessage()], $status);
        }
    }

    /**
     * POST /api/auth/verify-otp
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|digits:6',
        ]);

        try {
            $result = $this->pinService->verifyOtp($request->email, $request->otp);
            return response()->json($result, 200);
        } catch (Exception $e) {
            $status = $e->getCode() >= 400 && $e->getCode() <= 500 ? $e->getCode() : 400;
            return response()->json(['success' => false, 'message' => $e->getMessage()], $status);
        }
    }

    /**
     * POST /api/auth/reset-pin
     */
    public function resetPin(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'reset_token' => 'required|string',
            'new_pin' => 'required|digits:6',
            'new_pin_confirmation' => 'required|same:new_pin',
        ]);

        try {
            $result = $this->pinService->resetPin(
                $request->email,
                $request->reset_token,
                $request->new_pin
            );
            return response()->json($result, 200);
        } catch (Exception $e) {
            $status = $e->getCode() >= 400 && $e->getCode() <= 500 ? $e->getCode() : 400;
            return response()->json(['success' => false, 'message' => $e->getMessage()], $status);
        }
    }
}
