<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AdminProfileController extends Controller
{
    public function edit()
    {
        $user = Auth::user();

        return view('admin.profile.edit', compact('user'));
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

        return redirect()->back()
            ->with('success', 'Data login profil administrator berhasil diperbarui!');
    }
}
