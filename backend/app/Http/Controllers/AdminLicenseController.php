<?php

namespace App\Http\Controllers;

use App\Models\License;
use App\Models\Tenant;
use App\Services\LicenseService;
use Illuminate\Http\Request;
use Carbon\Carbon;

class AdminLicenseController extends Controller
{
    protected $licenseService;

    public function __construct(LicenseService $licenseService)
    {
        $this->licenseService = $licenseService;
    }

    public function index(Request $request)
    {
        $query = License::with(['tenant', 'subscription']);

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where('license_key', 'like', "%$search%");
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $licenses = $query->orderBy('created_at', 'desc')->paginate(10);
        $tenants = Tenant::where('status', 'active')->get();

        return view('admin.licenses.index', compact('licenses', 'tenants'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'tenant_id' => 'required|exists:tenants,id',
            'plan' => 'required|in:trial,monthly,yearly,lifetime',
            'device_limit' => 'required|integer|min:1',
            'expires_in_days' => 'nullable|integer|min:1',
        ]);

        $this->licenseService->generateLicense(
            $request->tenant_id,
            $request->plan,
            $request->device_limit,
            $request->expires_in_days
        );

        return redirect()->route('admin.licenses.index')->with('success', 'Lisensi baru berhasil dibuat!');
    }

    public function show($id)
    {
        $license = License::with(['tenant', 'subscription', 'devices'])->findOrFail($id);
        return view('admin.licenses.show', compact('license'));
    }

    public function resetDevice($licenseId, $deviceId)
    {
        $this->licenseService->resetDevice($licenseId, $deviceId);
        return redirect()->back()->with('success', 'Perangkat berhasil di-reset untuk lisensi ini!');
    }

    public function suspend($id)
    {
        $license = License::findOrFail($id);
        $license->update(['status' => 'REVOKED']);

        return redirect()->back()->with('success', 'Lisensi berhasil ditangguhkan!');
    }

    public function renew(Request $request, $id)
    {
        $request->validate([
            'plan' => 'required|in:monthly,yearly,lifetime',
        ]);

        $license = License::findOrFail($id);
        
        $expiresAt = null;
        if ($request->plan === 'monthly') {
            $expiresAt = Carbon::now()->addMonth();
        } elseif ($request->plan === 'yearly') {
            $expiresAt = Carbon::now()->addYear();
        } else {
            $expiresAt = Carbon::parse('2099-12-31 23:59:59');
        }

        $license->update([
            'expires_at' => $expiresAt,
            'status' => 'ACTIVE',
        ]);

        if ($license->subscription) {
            $license->subscription->update([
                'plan' => $request->plan,
                'status' => 'active',
                'expires_at' => $expiresAt,
            ]);
        }

        return redirect()->back()->with('success', 'Lisensi berhasil diperbarui!');
    }
}
