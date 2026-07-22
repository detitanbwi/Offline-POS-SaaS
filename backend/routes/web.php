<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminDeviceController;
use App\Http\Controllers\AdminInvoiceController;
use App\Http\Controllers\AdminLicenseTokenController;
use App\Http\Controllers\AdminPackageController;
use App\Http\Controllers\AdminProfileController;
use App\Http\Controllers\AdminSubscriptionController;
use App\Http\Controllers\AuditLogController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\TenantController;
use Illuminate\Support\Facades\Route;

// Redirect root to dashboard/login
Route::get('/', function () {
    return redirect()->route('admin.dashboard');
});

// Alias for default Laravel auth redirect
Route::get('/login', function () {
    return redirect()->route('admin.login');
})->name('login');

// Admin login routes
Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login']);
Route::post('/admin/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');

// Admin protected group
Route::middleware(['auth', 'admin'])->prefix('admin')->name('admin.')->group(function () {
    // Dashboard
    Route::get('/', [DashboardController::class, 'index'])->name('dashboard');

    // Profile & Credentials Editing
    Route::get('/profile', [AdminProfileController::class, 'edit'])->name('profile.edit');
    Route::put('/profile', [AdminProfileController::class, 'update'])->name('profile.update');

    // Tenants CRUD & Actions
    Route::post('/tenants/{tenant}/suspend', [TenantController::class, 'suspend'])->name('tenants.suspend');
    Route::post('/tenants/{tenant}/reactivate', [TenantController::class, 'reactivate'])->name('tenants.reactivate');
    Route::post('/tenants/{tenant}/generate-license', [TenantController::class, 'generateLicense'])->name('tenants.generate-license');
    Route::resource('tenants', TenantController::class);

    // Packages CRUD
    Route::resource('packages', AdminPackageController::class);

    // Invoices & Actions
    Route::post('/invoices/{invoice}/upload-proof', [AdminInvoiceController::class, 'uploadPaymentProof'])->name('invoices.upload-proof');
    Route::post('/invoices/{invoice}/mark-paid', [AdminInvoiceController::class, 'markAsPaid'])->name('invoices.mark-paid');
    Route::post('/invoices/{invoice}/cancel', [AdminInvoiceController::class, 'cancel'])->name('invoices.cancel');
    Route::get('/invoices/{invoice}/download-pdf', [AdminInvoiceController::class, 'downloadPdf'])->name('invoices.download-pdf');
    Route::resource('invoices', AdminInvoiceController::class)->only(['index', 'create', 'store', 'show']);

    // Subscriptions (read only)
    Route::get('/subscriptions', [AdminSubscriptionController::class, 'index'])->name('subscriptions.index');
    Route::get('/subscriptions/{subscription}', [AdminSubscriptionController::class, 'show'])->name('subscriptions.show');

    // License Tokens & Actions
    Route::post('/tokens/{token}/reset-device', [AdminLicenseTokenController::class, 'resetDevice'])->name('tokens.reset-device');
    Route::post('/tokens/{token}/revoke', [AdminLicenseTokenController::class, 'revoke'])->name('tokens.revoke');
    Route::get('/tokens', [AdminLicenseTokenController::class, 'index'])->name('tokens.index');
    Route::get('/tokens/{token}', [AdminLicenseTokenController::class, 'show'])->name('tokens.show');

    // Devices (read only)
    Route::get('/devices', [AdminDeviceController::class, 'index'])->name('devices.index');
    Route::get('/devices/{device}', [AdminDeviceController::class, 'show'])->name('devices.show');

    // Audit Logs
    Route::get('/audit-logs', [AuditLogController::class, 'index'])->name('audit-logs.index');
});
