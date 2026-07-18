<?php

namespace App\Http\Controllers;

use App\Enums\DeviceStatus;
use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TenantStatus;
use App\Enums\TokenStatus;
use App\Models\AuditLog;
use App\Models\Device;
use App\Models\Invoice;
use App\Models\LicenseToken;
use App\Models\Subscription;
use App\Models\Tenant;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_tenants' => Tenant::count(),
            'active_tenants' => Tenant::where('status', TenantStatus::ACTIVE)->count(),
            'total_invoices' => Invoice::count(),
            'unpaid_invoices' => Invoice::where('status', InvoiceStatus::UNPAID)->count(),
            'paid_invoices' => Invoice::where('status', InvoiceStatus::PAID)->count(),
            'active_subscriptions' => Subscription::where('status', SubscriptionStatus::ACTIVE)->count(),
            'total_tokens' => LicenseToken::count(),
            'active_tokens' => LicenseToken::where('status', TokenStatus::ACTIVE)->count(),
            'available_tokens' => LicenseToken::where('status', TokenStatus::AVAILABLE)->count(),
            'total_devices' => Device::where('status', DeviceStatus::ACTIVE)->count(),
            'recent_activities' => AuditLog::with('tenant')
                ->orderBy('created_at', 'desc')
                ->take(10)
                ->get(),
        ];

        return view('admin.dashboard', compact('stats'));
    }
}
