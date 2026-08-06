<?php

namespace App\Services;

use App\Mail\DeviceResetOtpMail;
use App\Models\DeviceResetOtp;
use App\Models\LicenseToken;
use App\Models\User;
use Exception;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class DeviceResetService
{
    const MAX_ATTEMPTS = 3;
    const OTP_EXPIRY_MINUTES = 5;

    public function __construct(
        protected LicenseService $licenseService
    ) {}

    /**
     * Request OTP for device reset
     */
    public function requestOtp(string $email, string $password, string $tokenKey): array
    {
        $user = User::where('email', $email)->first();

        if (! $user || ! Hash::check($password, $user->password)) {
            throw new Exception('Email atau password salah.', 401);
        }

        $token = LicenseToken::where('token_key', $tokenKey)->first();

        if (! $token) {
            throw new Exception('Token lisensi tidak valid.', 404);
        }

        if ($user->tenant_id !== $token->tenant_id) {
            throw new Exception('Anda tidak memiliki akses ke lisensi ini.', 403);
        }

        // Hapus OTP lama yang belum selesai
        DeviceResetOtp::where('email', $email)
            ->where('token_key', $tokenKey)
            ->delete();

        // Generate 6 digit angka acak (000000 - 999999)
        $otpCode = sprintf('%06d', mt_rand(0, 999999));

        DeviceResetOtp::create([
            'email' => $email,
            'token_key' => $tokenKey,
            'otp_code' => $otpCode,
            'expires_at' => now()->addMinutes(self::OTP_EXPIRY_MINUTES),
            'attempts' => 0,
            'is_verified' => false,
        ]);

        try {
            Mail::to($user->email)->send(new DeviceResetOtpMail($otpCode, $user->name));
        } catch (Exception $mailException) {
            Log::warning("Gagal mengirim email OTP ke {$email}. Error: " . $mailException->getMessage());
        }

        Log::info("Device Reset OTP untuk email [{$email}] dan token [{$tokenKey}]: {$otpCode}");

        return [
            'success' => true,
            'message' => 'Kode OTP telah dikirimkan ke email Anda.',
        ];
    }

    /**
     * Verify OTP and reset device
     */
    public function verifyOtp(string $email, string $tokenKey, string $otpCode): array
    {
        $record = DeviceResetOtp::where('email', $email)
            ->where('token_key', $tokenKey)
            ->latest()
            ->first();

        if (! $record) {
            throw new Exception('Permintaan OTP tidak ditemukan.', 404);
        }

        if (now()->greaterThan($record->expires_at)) {
            $record->delete();
            throw new Exception('Kode OTP sudah kedaluwarsa. Silakan minta OTP baru.', 410);
        }

        if ($record->attempts >= self::MAX_ATTEMPTS) {
            $record->delete();
            throw new Exception('Batas maksimal percobaan salah tercapai. Silakan minta OTP baru.', 429);
        }

        if ($record->otp_code !== $otpCode) {
            $record->increment('attempts');
            $remaining = self::MAX_ATTEMPTS - $record->attempts;
            throw new Exception("Kode OTP tidak valid. Sisa percobaan: {$remaining} kali.", 422);
        }

        $record->update(['is_verified' => true]);

        // Proceed to reset device
        $token = LicenseToken::where('token_key', $tokenKey)->first();
        if (! $token) {
            throw new Exception('Token lisensi tidak valid.', 404);
        }

        $resetSuccess = $this->licenseService->resetDevice($token->id);

        if (! $resetSuccess) {
            throw new Exception('Gagal mereset perangkat. Silakan hubungi admin.', 500);
        }

        $record->delete();

        return [
            'success' => true,
            'message' => 'Perangkat berhasil di-reset. Anda sekarang dapat menggunakan lisensi ini.',
        ];
    }
}
