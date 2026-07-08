<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\License;
use Carbon\Carbon;

/**
 * Legacy License Controller
 * 
 * Note: License generation is now handled by AdminLicenseController.
 * Device activation is now handled by ActivationController + LicenseService.
 * This controller only retains the dashboard view and force-expire action for the old web UI.
 */
class LicenseController extends Controller
{
    public function index()
    {
        $licenses = License::orderBy('created_at', 'desc')->get();
        return view('licenses.index', compact('licenses'));
    }

    public function forceExpire($id)
    {
        $license = License::findOrFail($id);
        $license->update([
            'expires_at' => Carbon::now()->subMinute(),
        ]);

        return redirect()->back()->with('success', 'License successfully set to expired!');
    }
}