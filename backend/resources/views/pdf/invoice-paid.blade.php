<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Helvetica', 'Arial', sans-serif; font-size: 12px; color: #111827; line-height: 1.5; }
        .header { display: flex; justify-content: space-between; border-bottom: 3px solid #144683; padding-bottom: 16px; margin-bottom: 24px; }
        .company-name { font-size: 22px; font-weight: 700; color: #144683; }
        .company-subtitle { font-size: 11px; color: #6B7280; }
        .badge-paid { background-color: #DEF7EC; color: #03543F; padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 700; display: inline-block; }
        .invoice-meta { margin-bottom: 24px; }
        .invoice-meta table { width: 100%; }
        .invoice-meta td { padding: 3px 8px; font-size: 12px; vertical-align: top; }
        .meta-label { font-weight: 600; color: #6B7280; width: 120px; }
        .section-title { font-size: 14px; font-weight: 700; color: #144683; margin: 20px 0 10px; border-bottom: 1px solid #E5E7EB; padding-bottom: 6px; }
        .items-table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        .items-table th { background-color: #F1F5F9; padding: 10px 12px; text-align: left; font-size: 11px; font-weight: 600; color: #475569; border-bottom: 2px solid #E5E7EB; }
        .items-table td { padding: 10px 12px; border-bottom: 1px solid #F1F5F9; font-size: 12px; }
        .items-table .total-row td { font-weight: 700; font-size: 14px; border-top: 2px solid #144683; background-color: #F8FAFC; }
        .token-box { background-color: #F8FAFC; border: 1px solid #E5E7EB; border-radius: 6px; padding: 10px 16px; margin: 6px 0; font-family: 'Courier New', monospace; font-size: 14px; font-weight: 700; letter-spacing: 2px; }
        .activation-info { background-color: #FFF7ED; border: 1px solid #FDBA74; border-radius: 6px; padding: 16px; margin-top: 20px; }
        .activation-info h4 { color: #C2410C; margin-bottom: 8px; }
        .activation-info ol { padding-left: 20px; font-size: 11px; color: #78350F; }
        .footer { margin-top: 32px; border-top: 1px solid #E5E7EB; padding-top: 12px; text-align: center; font-size: 10px; color: #9CA3AF; }
    </style>
</head>
<body>
    <div class="header">
        <div>
            <div class="company-name">POS SaaS</div>
            <div class="company-subtitle">Sistem Point of Sale Modern</div>
        </div>
        <div style="text-align: right;">
            <div class="badge-paid">✓ LUNAS</div>
            <div style="font-size: 10px; color: #6B7280; margin-top: 4px;">{{ $invoice->paid_at?->format('d F Y, H:i') }}</div>
        </div>
    </div>

    <div class="invoice-meta">
        <table>
            <tr>
                <td style="width: 50%;">
                    <table>
                        <tr><td class="meta-label">No. Invoice</td><td style="font-weight: 700;">{{ $invoice->invoice_number }}</td></tr>
                        <tr><td class="meta-label">Tanggal</td><td>{{ $invoice->created_at->format('d F Y') }}</td></tr>
                        <tr><td class="meta-label">Status</td><td><span class="badge-paid">PAID</span></td></tr>
                        <tr><td class="meta-label">Metode Bayar</td><td>{{ ucfirst($invoice->payment_method ?? '-') }}</td></tr>
                    </table>
                </td>
                <td style="width: 50%;">
                    <table>
                        <tr><td class="meta-label">Tenant</td><td style="font-weight: 600;">{{ $tenant->name }}</td></tr>
                        <tr><td class="meta-label">Pemilik</td><td>{{ $tenant->owner_name }}</td></tr>
                        <tr><td class="meta-label">Email</td><td>{{ $tenant->email }}</td></tr>
                        <tr><td class="meta-label">Telepon</td><td>{{ $tenant->phone ?? '-' }}</td></tr>
                    </table>
                </td>
            </tr>
        </table>
    </div>

    <div class="section-title">Daftar Paket</div>
    <table class="items-table">
        <thead>
            <tr><th>Paket</th><th>Durasi</th><th style="text-align:center;">Qty</th><th style="text-align:right;">Harga Satuan</th><th style="text-align:right;">Total</th></tr>
        </thead>
        <tbody>
            @foreach ($items as $item)
            <tr>
                <td style="font-weight: 600;">{{ $item->package_name }}</td>
                <td>{{ $item->duration_days }} hari</td>
                <td style="text-align:center;">{{ $item->quantity }}</td>
                <td style="text-align:right;">Rp {{ number_format($item->unit_price, 0, ',', '.') }}</td>
                <td style="text-align:right; font-weight: 600;">Rp {{ number_format($item->total_price, 0, ',', '.') }}</td>
            </tr>
            @endforeach
            <tr class="total-row">
                <td colspan="4" style="text-align:right;">Grand Total</td>
                <td style="text-align:right; color: #144683;">Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
            </tr>
        </tbody>
    </table>

    @if ($tokens->count() > 0)
    <div class="section-title">Token Lisensi</div>
    <p style="font-size: 11px; color: #6B7280; margin-bottom: 12px;">Gunakan token berikut untuk mengaktifkan aplikasi POS pada perangkat Android Anda.</p>
    @foreach ($tokens as $token)
        <div class="token-box">{{ $token->token_key }}</div>
    @endforeach

    <div class="activation-info">
        <h4>Syarat Aktivasi</h4>
        <ol>
            <li>Buka aplikasi POS SaaS pada perangkat Android.</li>
            <li>Masukkan salah satu token lisensi di atas pada halaman aktivasi.</li>
            <li>Satu token hanya berlaku untuk satu perangkat.</li>
            <li>Token yang sudah diaktifkan tidak dapat digunakan pada perangkat lain.</li>
            <li>Hubungi admin untuk melakukan reset perangkat jika diperlukan.</li>
        </ol>
    </div>
    @endif

    <div class="footer">
        <p>Invoice ini diterbitkan secara otomatis oleh POS SaaS System.</p>
        <p>{{ $invoice->invoice_number }} — Dicetak pada {{ now()->format('d F Y, H:i') }}</p>
    </div>
</body>
</html>
