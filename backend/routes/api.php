<?php

use App\Http\Controllers\ActivationController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PinRecoveryController;
use Illuminate\Support\Facades\Route;

Route::middleware('throttle:60,1')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);

    // Password Recovery Routes
    Route::post('/password/forgot', [\App\Http\Controllers\PasswordRecoveryController::class, 'requestOtp']);
    Route::post('/password/verify-otp', [\App\Http\Controllers\PasswordRecoveryController::class, 'verifyOtp']);
    Route::post('/password/reset', [\App\Http\Controllers\PasswordRecoveryController::class, 'resetPassword']);

    // Fitur Lupa PIN (OTP via Email)
    Route::prefix('auth')->group(function () {
        Route::post('/request-otp', [PinRecoveryController::class, 'requestOtp']);
        Route::post('/verify-otp', [PinRecoveryController::class, 'verifyOtp']);
        Route::post('/reset-pin', [PinRecoveryController::class, 'resetPin']);
        
        // Fitur Reset Perangkat (OTP via Email)
        Route::post('/request-device-reset-otp', [ActivationController::class, 'requestResetOtp']);
        Route::post('/verify-device-reset-otp', [ActivationController::class, 'verifyResetOtp']);
    });
});

Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
    Route::get('/license-info', [ActivationController::class, 'getLicenseInfo']);
    Route::post('/activate', [ActivationController::class, 'activate']);
    Route::post('/validate-license', [ActivationController::class, 'validateLicense']);
    Route::post('/license-logs/sync', [\App\Http\Controllers\LicenseLogController::class, 'sync']);
});
