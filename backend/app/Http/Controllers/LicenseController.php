<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\License;
use Illuminate\Support\Str;
use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;

class LicenseController extends Controller
{
    public function index()
    {
        $licenses = License::orderBy('created_at', 'desc')->get();
        return view('licenses.index', compact('licenses'));
    }

    public function generate()
    {
        License::create([
            'license_key' => 'LIC-' . strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4)),
            'status' => 'AVAILABLE',
            'expires_at' => Carbon::now()->addDays(30),
        ]);

        return redirect()->back()->with('success', 'License Key successfully generated!');
    }

    public function forceExpire($id)
    {
        $license = License::findOrFail($id);
        $license->update([
            'expires_at' => Carbon::now()->subMinute(),
        ]);

        return redirect()->back()->with('success', 'License successfully set to expired!');
    }

    public function activate(Request $request)
    {
        $request->validate([
            'license_key' => 'required|string',
            'device_id' => 'required|string',
        ]);

        $license = License::where('license_key', $request->license_key)->first();
        $user = Auth::user(); // Diambil dari token Sanctum

        if (!$license || $license->status === 'REVOKED') {
            return response()->json(['success' => false, 'message' => 'Lisensi tidak valid/dicabut!'], 403);
        }

        if ($license->device_id !== null && $license->device_id !== $request->device_id) {
            return response()->json(['success' => false, 'message' => 'Lisensi terdaftar di perangkat lain!'], 400);
        }

        // Bind lisensi ke User dan Device
        $license->device_id = $request->device_id;
        $license->user_id = $user->id; 
        $license->status = 'ACTIVE';
        $license->save();

        // GENERATE STANDARD JWT (HS256) - FOR OFFLINE VALIDATION (SIMULATION ONLY)
        $base64UrlEncode = function ($data) {
            return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($data));
        };

        $header = json_encode([
            'alg' => 'HS256',
            'typ' => 'JWT'
        ]);

        $payload = json_encode([
            'license_key' => $license->license_key,
            'android_id' => $license->device_id,
            'exp' => $license->expires_at->timestamp
        ]);

        $base64UrlHeader = $base64UrlEncode($header);
        $base64UrlPayload = $base64UrlEncode($payload);

        // WARNING: This secret key is for simulation/MVP purposes only. Do not use in production!
        $secretKey = 'SIMULATION_ONLY_NOT_FOR_PRODUCTION_SECRET_KEY_9921';

        $signature = hash_hmac('sha256', $base64UrlHeader . '.' . $base64UrlPayload, $secretKey, true);
        $base64UrlSignature = $base64UrlEncode($signature);

        $secureOfflineToken = $base64UrlHeader . '.' . $base64UrlPayload . '.' . $base64UrlSignature;

        return response()->json([
            'success' => true,
            'message' => 'Aktivasi berhasil!',
            'offline_token' => $secureOfflineToken,
            'expires_at' => $license->expires_at->toIso8601String(),
        ]);
    }
}