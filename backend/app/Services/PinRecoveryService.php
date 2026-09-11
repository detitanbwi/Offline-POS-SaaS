<?php

namespace App\Services;

use App\Mail\PinResetOtpMail;
use App\Models\PinResetOtp;
use App\Models\User;
use Exception;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class PinRecoveryService
{
    const MAX_ATTEMPTS = 3;
    const OTP_EXPIRY_MINUTES = 5;

    /**
     * 1. Generate & Kirim OTP ke Email Owner/User
     */
    public function requestOtp(string $email): array
    {
        // 1. Validasi keberadaan email di sistem
        $user = User::where('email', $email)->first();
        if (! $user) {
            throw new Exception('Email tidak ditemukan dalam sistem.', 404);
        }

        // 2. Hapus OTP lama yang belum selesai untuk email ini
        PinResetOtp::where('email', $email)->delete();

        // 3. Generate 6 digit angka acak (000000 - 999999)
        $otpCode = sprintf('%06d', mt_rand(0, 999999));

        // 4. Simpan ke database dengan expiry 5 menit
        PinResetOtp::create([
            'email' => $email,
            'otp_code' => $otpCode,
            'expires_at' => now()->addMinutes(self::OTP_EXPIRY_MINUTES),
            'attempts' => 0,
            'is_verified' => false,
        ]);

        // 5. Kirim email OTP secara asinkron via Queue (dengan fallback logging untuk mode Offline/Dev)
        try {
            Mail::to($user->email)->queue(new PinResetOtpMail($otpCode, $user->name));
        } catch (Exception $mailException) {
            Log::warning("Gagal memasukkan email OTP ke antrean untuk {$email}. Menggunakan log sebagai fallback. Error: " . $mailException->getMessage());
        }

        // Selalu catat kode OTP di log aplikasi agar memudahkan pengujian offline
        Log::info("PIN Reset OTP untuk email [{$email}]: {$otpCode}");

        return [
            'success' => true,
            'message' => 'Kode OTP telah dikirimkan ke email Anda.',
            // Catatan: Di production, jangan kembalikan otp_code di response JSON
        ];
    }

    /**
     * 2. Verifikasi OTP 6 Digit
     */
    public function verifyOtp(string $email, string $otpCode): array
    {
        $record = PinResetOtp::where('email', $email)->latest()->first();

        // Validasi keberadaan request OTP
        if (! $record) {
            throw new Exception('Permintaan OTP tidak ditemukan. Silakan minta OTP baru.', 404);
        }

        // Validasi masa berlaku (Expired)
        if (now()->greaterThan($record->expires_at)) {
            $record->delete();
            throw new Exception('Kode OTP sudah kedaluwarsa. Silakan minta OTP baru.', 410);
        }

        // Validasi batas maksimal percobaan (Rate limiting per OTP)
        if ($record->attempts >= self::MAX_ATTEMPTS) {
            $record->delete();
            throw new Exception('Batas maksimal percobaan salah tercapai (maksimal ' . self::MAX_ATTEMPTS . 'x). Silakan minta OTP baru.', 429);
        }

        // Validasi kecocokan kode OTP
        if ($record->otp_code !== $otpCode) {
            $record->increment('attempts');
            $remaining = self::MAX_ATTEMPTS - $record->attempts;
            throw new Exception("Kode OTP tidak valid. Sisa percobaan: {$remaining} kali.", 422);
        }

        // OTP Valid: buat reset_token acak agar user bisa lanjut ke tahap pembuatan PIN baru
        $resetToken = Str::uuid()->toString();
        $record->update([
            'is_verified' => true,
            'reset_token' => $resetToken,
            'expires_at' => now()->addMinutes(10), // Beri waktu ekstra 10 menit untuk mengisi PIN baru
        ]);

        return [
            'success' => true,
            'message' => 'Verifikasi OTP berhasil.',
            'reset_token' => $resetToken,
        ];
    }

    /**
     * 3. Simpan PIN Baru (Dengan Proteksi PIN Default/Lemah)
     */
    public function resetPin(string $email, string $resetToken, string $newPin): array
    {
        // 1. Validasi PIN tidak boleh angka mudah/default
        $this->validateStrongPin($newPin);

        // 2. Cek validitas token hasil verifikasi OTP
        $record = PinResetOtp::where('email', $email)
            ->where('reset_token', $resetToken)
            ->where('is_verified', true)
            ->first();

        if (! $record || now()->greaterThan($record->expires_at)) {
            throw new Exception('Sesi reset PIN tidak valid atau sudah habis masa berlakunya. Silakan mulai ulang.', 403);
        }

        // 3. Update PIN user (gunakan hashing agar aman di database)
        $user = User::where('email', $email)->first();
        if (! $user) {
            throw new Exception('User tidak ditemukan.', 404);
        }

        $user->update([
            'pin' => Hash::make($newPin),
        ]);

        // 4. Hapus record OTP yang sudah terpakai
        PinResetOtp::where('email', $email)->delete();

        return [
            'success' => true,
            'message' => 'PIN berhasil diperbarui. Silakan login dengan PIN baru Anda.',
        ];
    }

    /**
     * Helper proteksi PIN default & mudah ditebak
     */
    private function validateStrongPin(string $pin): void
    {
        $weakPins = [
            '123456', '654321', '000000', '111111', '222222',
            '333333', '444444', '555555', '666666', '777777',
            '888888', '999999', '121212', '101010',
        ];

        if (in_array($pin, $weakPins)) {
            throw new Exception('PIN terlalu mudah ditebak. Jangan gunakan angka default atau berurutan (misal: 123456/000000).', 422);
        }
    }
}
