<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
use App\Models\SystemSetting;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AdminProfileController extends Controller
{
    public function edit()
    {
        $user = Auth::user();

        $providerSettings = [
            'company_name' => SystemSetting::getVal('company_name', 'Wirodev Digital Architecture'),
            'company_subtitle' => SystemSetting::getVal('company_subtitle', 'Pusat Pengembangan Sistem SaaS'),
            'company_email' => SystemSetting::getVal('company_email', 'billing@wirodev.com'),
            'company_phone' => SystemSetting::getVal('company_phone', ''),
            'company_address' => SystemSetting::getVal('company_address', ''),
            'bank_name' => SystemSetting::getVal('bank_name', 'Bank Mandiri'),
            'bank_account_number' => SystemSetting::getVal('bank_account_number', '8899-0022-1133'),
            'bank_account_holder' => SystemSetting::getVal('bank_account_holder', 'PT Wirodev Digital Architecture'),
        ];

        return view('admin.profile.edit', compact('user', 'providerSettings'));
    }

    public function update(UpdateProfileRequest $request)
    {
        $user = Auth::user();

        if ($request->filled('password')) {
            if (! Hash::check($request->current_password, $user->password)) {
                return redirect()->back()
                    ->withInput()
                    ->withErrors(['current_password' => 'Password saat ini yang Anda masukkan salah.']);
            }
        }

        $user->name = $request->name;
        $user->email = $request->email;

        if ($request->filled('password')) {
            $user->password = Hash::make($request->password);
        }

        $user->save();

        // Update provider & bank system settings
        $keys = [
            'company_name',
            'company_subtitle',
            'company_email',
            'company_phone',
            'company_address',
            'bank_name',
            'bank_account_number',
            'bank_account_holder',
        ];

        foreach ($keys as $key) {
            if ($request->has($key)) {
                SystemSetting::setVal($key, $request->input($key, ''));
            }
        }

        return redirect()->back()
            ->with('success', 'Profil administrator dan pengaturan penyedia layanan berhasil diperbarui!');
    }
}
