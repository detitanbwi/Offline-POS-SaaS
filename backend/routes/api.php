<?php

use App\Http\Controllers\ActivationController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PinRecoveryController;
use Illuminate\Support\Facades\Route;

Route::middleware('throttle:10,1')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);

    // Fitur Lupa PIN (OTP via Email)
    Route::prefix('auth')->group(function () {
        Route::post('/request-otp', [PinRecoveryController::class, 'requestOtp']);
        Route::post('/verify-otp', [PinRecoveryController::class, 'verifyOtp']);
        Route::post('/reset-pin', [PinRecoveryController::class, 'resetPin']);
    });
});

Route::middleware(['auth:sanctum', 'throttle:30,1'])->group(function () {
    Route::get('/license-info', [ActivationController::class, 'getLicenseInfo']);
    Route::post('/activate', [ActivationController::class, 'activate']);
    Route::post('/validate-license', [ActivationController::class, 'validateLicense']);
});
