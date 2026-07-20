<?php

use App\Http\Controllers\ActivationController;
use App\Http\Controllers\AuthController;
use Illuminate\Support\Facades\Route;

// Endpoint publik (untuk login) — rate limited: 10 requests per minute
Route::middleware('throttle:10,1')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
});

// Endpoint privat (wajib menyertakan Bearer Token di header) — rate limited: 30 requests per minute
Route::middleware(['auth:sanctum', 'throttle:30,1'])->group(function () {
    Route::get('/license-info', [ActivationController::class, 'getLicenseInfo']);
    Route::post('/activate', [ActivationController::class, 'activate']);
    Route::post('/validate-license', [ActivationController::class, 'validateLicense']);
});
