<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ActivationController;

// Endpoint publik (untuk login)
Route::post('/login', [AuthController::class, 'login']);

// Endpoint privat (wajib menyertakan Bearer Token di header)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/activate', [ActivationController::class, 'activate']);
    Route::post('/validate-license', [ActivationController::class, 'validateLicense']);
});