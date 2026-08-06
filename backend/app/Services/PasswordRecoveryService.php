<?php

namespace App\Services;

use App\Mail\PasswordResetOtpMail;
use App\Models\PasswordResetOtp;
use App\Models\User;
use Exception;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class PasswordRecoveryService
{
    const MAX_ATTEMPTS = 3;
    const OTP_EXPIRY_MINUTES = 5;

    public function requestOtp(string $email): array
    {
        $user = User::where('email', $email)->first();
        if (! $user) {
            throw new Exception('Email tidak ditemukan dalam sistem.', 404);
        }

        PasswordResetOtp::where('email', $email)->delete();

        $otpCode = sprintf('%06d', mt_rand(0, 999999));

        PasswordResetOtp::create([
            'email' => $email,
            'otp_code' => $otpCode,
            'expires_at' => now()->addMinutes(self::OTP_EXPIRY_MINUTES),
            'attempts' => 0,
            'is_verified' => false,
        ]);

        try {
            Mail::to($user->email)->send(new PasswordResetOtpMail($otpCode, $user->name));
        } catch (Exception $mailException) {
            Log::warning("Gagal mengirim email OTP ke {$email}. Menggunakan log sebagai fallback. Error: " . $mailException->getMessage());
        }

        Log::info("Password Reset OTP untuk email [{$email}]: {$otpCode}");

        return [
            'success' => true,
            'message' => 'Kode OTP telah dikirimkan ke email Anda.',
        ];
    }

    public function verifyOtp(string $email, string $otpCode): array
    {
        $record = PasswordResetOtp::where('email', $email)->latest()->first();

        if (! $record) {
            throw new Exception('Permintaan OTP tidak ditemukan. Silakan minta OTP baru.', 404);
        }

        if (now()->greaterThan($record->expires_at)) {
            $record->delete();
            throw new Exception('Kode OTP sudah kedaluwarsa. Silakan minta OTP baru.', 410);
        }

        if ($record->attempts >= self::MAX_ATTEMPTS) {
            $record->delete();
            throw new Exception('Batas maksimal percobaan salah tercapai (maksimal ' . self::MAX_ATTEMPTS . 'x). Silakan minta OTP baru.', 429);
        }

        if ($record->otp_code !== $otpCode) {
            $record->increment('attempts');
            $remaining = self::MAX_ATTEMPTS - $record->attempts;
            throw new Exception("Kode OTP tidak valid. Sisa percobaan: {$remaining} kali.", 422);
        }

        $resetToken = Str::uuid()->toString();
        $record->update([
            'is_verified' => true,
            'reset_token' => $resetToken,
            'expires_at' => now()->addMinutes(10),
        ]);

        return [
            'success' => true,
            'message' => 'Verifikasi OTP berhasil.',
            'reset_token' => $resetToken,
        ];
    }

    public function resetPassword(string $email, string $resetToken, string $newPassword): array
    {
        if (strlen($newPassword) < 6) {
            throw new Exception('Password minimal 6 karakter.', 422);
        }

        $record = PasswordResetOtp::where('email', $email)
            ->where('reset_token', $resetToken)
            ->where('is_verified', true)
            ->first();

        if (! $record || now()->greaterThan($record->expires_at)) {
            throw new Exception('Sesi reset password tidak valid atau sudah habis masa berlakunya. Silakan mulai ulang.', 403);
        }

        $user = User::where('email', $email)->first();
        if (! $user) {
            throw new Exception('User tidak ditemukan.', 404);
        }

        $user->update([
            'password' => Hash::make($newPassword),
        ]);

        PasswordResetOtp::where('email', $email)->delete();

        return [
            'success' => true,
            'message' => 'Password berhasil diperbarui. Silakan login dengan password baru Anda.',
        ];
    }
}
