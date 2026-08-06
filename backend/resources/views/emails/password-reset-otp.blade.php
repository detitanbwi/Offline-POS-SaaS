<!DOCTYPE html>
<html>
<head>
    <title>Kode OTP Reset Password</title>
</head>
<body>
    <h2>Halo, {{ $userName }}</h2>
    <p>Kami menerima permintaan untuk mengatur ulang password akun Anda.</p>
    <p>Berikut adalah kode OTP Anda:</p>
    <h3 style="background-color: #f4f4f4; padding: 10px; display: inline-block; letter-spacing: 2px;">{{ $otpCode }}</h3>
    <p>Kode ini hanya berlaku selama 5 menit. Jangan berikan kode ini kepada siapapun.</p>
    <p>Jika Anda tidak merasa meminta reset password, silakan abaikan email ini.</p>
    <br>
    <p>Terima kasih,</p>
    <p>Tim SaaS POS Offline</p>
</body>
</html>
