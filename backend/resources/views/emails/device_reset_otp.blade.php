<x-mail::message>
# Halo, {{ $userName }}

Anda menerima email ini karena ada permintaan untuk mereset perangkat dari lisensi Anda.

Berikut adalah kode OTP Anda:

<x-mail::panel>
# {{ $otpCode }}
</x-mail::panel>

Kode ini akan kedaluwarsa dalam 5 menit. Jika Anda tidak meminta reset perangkat ini, abaikan email ini.

Terima kasih,<br>
Tim {{ config('app.name') }}
</x-mail::message>
