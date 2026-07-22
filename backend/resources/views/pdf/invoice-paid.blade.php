<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Faktur Pembelian Lisensi SaaS - {{ $invoice->invoice_number }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Helvetica Neue', 'Helvetica', 'Arial', sans-serif; font-size: 12px; color: #1e293b; line-height: 1.5; padding: 32px; }
        
        .header-title { font-size: 20px; font-weight: 800; color: #0f172a; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
        .invoice-info { font-size: 12px; margin-bottom: 20px; line-height: 1.6; }
        .invoice-info strong { color: #0f172a; }
        .status-paid { color: #15803d; font-weight: 700; background-color: #dcfce7; padding: 2px 8px; border-radius: 4px; display: inline-block; }

        .parties-grid { width: 100%; margin-bottom: 24px; border-collapse: collapse; }
        .parties-grid td { vertical-align: top; width: 50%; }
        .section-heading { font-size: 13px; font-weight: 700; color: #0f172a; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.3px; }
        .party-box p { margin-bottom: 2px; color: #475569; }

        .items-section-title { font-size: 14px; font-weight: 700; color: #0f172a; margin-bottom: 10px; border-bottom: 2px solid #e2e8f0; padding-bottom: 4px; }
        .items-table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        .items-table th { background-color: #f8fafc; padding: 8px 10px; text-align: left; font-size: 11px; font-weight: 700; color: #475569; border-bottom: 1px solid #cbd5e1; }
        .items-table td { padding: 10px; border-bottom: 1px solid #e2e8f0; font-size: 12px; color: #334155; }
        
        .totals-table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
        .totals-table td { padding: 4px 10px; font-size: 12px; }
        .totals-label { text-align: right; font-weight: 600; color: #475569; width: 70%; }
        .totals-value { text-align: right; font-weight: 700; color: #0f172a; }
        .grand-total-row td { font-size: 14px; font-weight: 800; color: #0284c7; border-top: 2px solid #0284c7; padding-top: 8px; }

        .tokens-box { background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin-bottom: 24px; }
        .tokens-title { font-size: 14px; font-weight: 700; color: #0f172a; margin-bottom: 6px; }
        .tokens-intro { font-size: 11px; color: #475569; margin-bottom: 14px; }
        .token-item { margin-bottom: 12px; }
        .token-label { font-size: 12px; font-weight: 600; color: #334155; margin-bottom: 4px; }
        .token-key { background-color: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 14px; font-family: 'Courier New', monospace; font-size: 14px; font-weight: 700; color: #0284c7; letter-spacing: 1.5px; display: inline-block; }

        .terms-box { background-color: #fefce8; border: 1px solid #fef08a; border-radius: 8px; padding: 14px; }
        .terms-title { font-size: 12px; font-weight: 700; color: #854d0e; margin-bottom: 6px; }
        .terms-list { padding-left: 18px; font-size: 11px; color: #713f12; }
        .terms-list li { margin-bottom: 4px; }

        .footer { text-align: center; font-size: 10px; color: #94a3b8; margin-top: 32px; border-top: 1px solid #e2e8f0; padding-top: 12px; }
    </style>
</head>
<body>
    <div class="header-title">FAKTUR PEMBELIAN LISENSI SAAS</div>
    <div class="invoice-info">
        <div><strong>Nomor Faktur:</strong> {{ $invoice->invoice_number }}</div>
        <div><strong>Tanggal Penerbitan:</strong> {{ $invoice->created_at->translatedFormat('d F Y') }}</div>
        <div><strong>Status Pembayaran:</strong> <span class="status-paid">LUNAS (PAID)</span></div>
    </div>

    <table class="parties-grid">
        <tr>
            <td>
                <div class="section-heading">Penyedia Layanan:</div>
                <div class="party-box">
                    <p style="font-weight: 700; color: #0f172a;">Wirodev Digital Architecture</p>
                    <p>Pusat Pengembangan Sistem SaaS</p>
                    <p>Email: billing@wirodev.com</p>
                </div>
            </td>
            <td>
                <div class="section-heading">Ditagihkan Kepada:</div>
                <div class="party-box">
                    <p style="font-weight: 700; color: #0f172a;">{{ $tenant->store_name ?? $tenant->name }}</p>
                    <p>Pengusaha/Tenant POS UMKM</p>
                    <p>Email: {{ $tenant->email }}</p>
                </div>
            </td>
        </tr>
    </table>

    <div class="items-section-title">Rincian Transaksi Keranjang Lisensi</div>
    <table class="items-table">
        <thead>
            <tr>
                <th>Item Paket Lisensi</th>
                <th>Catatan Mesin Klien</th>
                <th style="text-align: center;">Durasi</th>
                <th style="text-align: right;">Harga Satuan</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($items as $item)
            <tr>
                <td style="font-weight: 600;">{{ $item->package_name }}</td>
                <td>{{ $item->client_note ?? '-' }}</td>
                <td style="text-align: center;">{{ $item->duration_days }} Hari</td>
                <td style="text-align: right;">Rp{{ number_format($item->unit_price, 0, ',', '.') }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>

    <table class="totals-table">
        <tr>
            <td class="totals-label">Total Nilai Lisensi:</td>
            <td class="totals-value">Rp{{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
        </tr>
        <tr class="grand-total-row">
            <td class="totals-label">GRAND TOTAL PEMBAYARAN:</td>
            <td class="totals-value">Rp{{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
        </tr>
    </table>

    @if ($tokens->count() > 0)
    <div class="tokens-box">
        <div class="tokens-title">Token Lisensi yang Diterbitkan (Rasio 1 Token = 1 Perangkat)</div>
        <p class="tokens-intro">Berikut adalah token enkripsi kriptografi hasil pemrosesan provisioning backend yang siap disalin dan dimasukkan pada masing-masing mesin tablet kasir luring:</p>
        
        @foreach ($tokens as $token)
            <div class="token-item">
                <div class="token-label">
                    Token {{ $token->client_note ? $token->client_note : ($token->subscription?->package_name ?? 'Mesin Kasir') }} ({{ $token->subscription?->package_name ?? 'Paket' }}):
                </div>
                <div class="token-key">{{ $token->token_key }}</div>
            </div>
        @endforeach
    </div>

    <div class="terms-box">
        <div class="terms-title">Syarat dan Ketentuan Aktivasi Lisensi:</div>
        <ol class="terms-list">
            <li>Setiap token hanya dapat mengunci tepat 1 UUID perangkat keras secara permanen hingga masa aktif habis.</li>
            <li>Pencabutan perangkat (Device Revoke) akibat kerusakan fisik tablet wajib diajukan melalui tim Customer Service SaaS pusat.</li>
        </ol>
    </div>
    @endif

    <div class="footer">
        Dokumen ini diterbitkan secara otomatis - {{ $invoice->invoice_number }}
    </div>
</body>
</html>
