<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\TenantController;
use App\Http\Controllers\AdminLicenseController;
use App\Http\Controllers\AuditLogController;

// Redirect root to dashboard/login
Route::get('/', function () {
    return redirect()->route('admin.dashboard');
});

// Admin login routes
Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login']);
Route::post('/admin/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');

// Admin protected group
Route::middleware(['auth', 'admin'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/', [DashboardController::class, 'index'])->name('dashboard');
    Route::post('/settings', [DashboardController::class, 'updateSettings'])->name('settings.update');
    
    // Tenants CRUD & Actions
    Route::post('/tenants/{tenant}/suspend', [TenantController::class, 'suspend'])->name('tenants.suspend');
    Route::post('/tenants/{tenant}/reactivate', [TenantController::class, 'reactivate'])->name('tenants.reactivate');
    Route::resource('tenants', TenantController::class);
    
    // Licenses & Actions
    Route::post('/licenses/{license}/reset-device/{device}', [AdminLicenseController::class, 'resetDevice'])->name('licenses.reset-device');
    Route::post('/licenses/{license}/suspend', [AdminLicenseController::class, 'suspend'])->name('licenses.suspend');
    Route::post('/licenses/{license}/renew', [AdminLicenseController::class, 'renew'])->name('licenses.renew');
    Route::resource('licenses', AdminLicenseController::class);
    
    // Audit Logs
    Route::get('/audit-logs', [AuditLogController::class, 'index'])->name('audit-logs.index');
});
