<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        // Verifikasi keberadaan user dan kecocokan password
        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json(['success' => false, 'message' => 'Kredensial tidak valid'], 401);
        }

        // Cek status Tenant agar user tidak bisa login jika tenant tidak aktif/dihapus
        $tenant = $user->tenant;
        if (!$tenant || $tenant->status !== \App\Enums\TenantStatus::ACTIVE) {
            return response()->json([
                'success' => false, 
                'message' => 'Akun perusahaan Anda tidak aktif atau telah dihapus'
            ], 403);
        }

        // Buat token Sanctum
        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil',
            'access_token' => $token,
            'user' => $user->only('id', 'name', 'email'),
            'tenant' => $tenant ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'owner_name' => $tenant->owner_name,
                'store_name' => $tenant->store_name,
                'store_address' => $tenant->store_address,
                'phone' => $tenant->phone,
            ] : null,
            'license_tokens' => $tenant ? $tenant->licenseTokens()->whereIn('status', ['available', 'active'])->get()->map(fn ($t) => [
                'token_key' => $t->token_key,
                'status' => $t->status->value ?? $t->status,
                'expiry_date' => $t->subscription?->expiry_date?->toIso8601String(),
            ]) : [],
        ]);
    }
}
