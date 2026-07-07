<?php

namespace App\Http\Controllers;

use App\Models\Tenant;
use App\Models\License;
use App\Models\Device;
use App\Models\AuditLog;
use App\Models\SystemSetting;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_tenants' => Tenant::count(),
            'active_tenants' => Tenant::where('status', 'active')->count(),
            'total_licenses' => License::count(),
            'active_licenses' => License::where('status', 'ACTIVE')->count(),
            'total_devices' => Device::where('status', 'active')->count(),
            'recent_activities' => AuditLog::orderBy('created_at', 'desc')->take(10)->get(),
        ];

        $defaultTrialDays = SystemSetting::getVal('default_trial_days', 14);

        return view('admin.dashboard', compact('stats', 'defaultTrialDays'));
    }

    public function updateSettings(Request $request)
    {
        $request->validate([
            'default_trial_days' => 'required|integer|min:1',
        ]);

        SystemSetting::setVal('default_trial_days', $request->default_trial_days);

        return redirect()->back()->with('success', 'Pengaturan berhasil diperbarui!');
    }
}
