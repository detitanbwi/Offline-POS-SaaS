<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Kode OTP Pemulihan PIN</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; color: #333; }
        .email-container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 12px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
        .header { text-align: center; margin-bottom: 24px; }
        .header h2 { color: #1e3a8a; margin: 0; }
        .otp-box { background: #eff6ff; border: 2px dashed #3b82f6; border-radius: 8px; padding: 18px; text-align: center; margin: 24px 0; }
        .otp-code { font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #1d4ed8; }
        .footer { text-align: center; font-size: 12px; color: #6b7280; margin-top: 32px; }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="header">
            <h2>Pemulihan PIN POS</h2>
        </div>
        <p>Halo, <strong>{{ $userName }}</strong></p>
        <p>Kami menerima permintaan untuk mengatur ulang PIN masuk aplikasi POS Anda. Gunakan 6 digit kode OTP di bawah ini untuk melanjutkan proses verifikasi:</p>
        
        <div class="otp-box">
            <div class="otp-code">{{ $otpCode }}</div>
        </div>
        
        <p><strong>Penting:</strong> Kode ini hanya berlaku selama <strong>5 menit</strong>. Jangan pernah membagikan kode OTP ini kepada siapa pun demi keamanan toko Anda.</p>
        <p>Jika Anda tidak merasa melakukan permintaan ini, silakan abaikan pesan ini.</p>
        
        <div class="footer">
            &copy; {{ date('Y') }} Offline POS SaaS. All rights reserved.
        </div>
    </div>
</body>
</html>
