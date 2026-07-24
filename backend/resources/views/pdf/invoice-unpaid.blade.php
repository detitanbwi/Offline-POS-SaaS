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
        .status-unpaid { color: #b45309; font-weight: 700; background-color: #fef3c7; padding: 2px 8px; border-radius: 4px; display: inline-block; }

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

        .payment-box { background-color: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
        .payment-title { font-size: 14px; font-weight: 700; color: #0369a1; margin-bottom: 8px; }
        .payment-intro { font-size: 11px; color: #334155; margin-bottom: 12px; }
        .payment-details table { width: 100%; border-collapse: collapse; }
        .payment-details td { padding: 3px 0; font-size: 12px; }
        .pay-label { color: #64748b; font-weight: 500; width: 220px; }
        .pay-val { font-weight: 700; color: #0f172a; }
        .payment-footer { margin-top: 12px; font-size: 11px; color: #475569; line-height: 1.4; border-top: 1px dashed #cbd5e1; padding-top: 8px; }

        .footer { text-align: center; font-size: 10px; color: #94a3b8; margin-top: 32px; border-top: 1px solid #e2e8f0; padding-top: 12px; }
    </style>
</head>
<body>
    <div class="header-title">FAKTUR PEMBELIAN LISENSI SAAS</div>
    
    <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 12px;">
        <tr>
            <td style="width: 150px; padding: 3px 0; font-weight: 700; color: #0f172a;">Nomor Faktur:</td>
            <td style="padding: 3px 0; font-weight: 600; color: #0f172a;">{{ $invoice->invoice_number }}</td>
        </tr>
        <tr>
            <td style="padding: 3px 0; font-weight: 700; color: #0f172a;">Tanggal Penerbitan:</td>
            <td style="padding: 3px 0;">{{ $invoice->created_at->translatedFormat('d F Y') }}</td>
        </tr>
        <tr>
            <td style="padding: 3px 0; font-weight: 700; color: #0f172a;">Batas Waktu (Due Date):</td>
            <td style="padding: 3px 0;">{{ $invoice->due_date ? $invoice->due_date->translatedFormat('d F Y') : '-' }}</td>
        </tr>
        <tr>
            <td style="padding: 3px 0; font-weight: 700; color: #0f172a;">Status Pembayaran:</td>
            <td style="padding: 3px 0;"><span class="status-unpaid">BELUM DIBAYAR (UNPAID)</span></td>
        </tr>
    </table>

    <table class="parties-grid">
        <tr>
            <td>
                <div class="section-heading">Penyedia Layanan:</div>
                <div class="party-box">
                    <p style="font-weight: 700; color: #0f172a;">{{ $providerSettings['company_name'] ?? 'Wirodev Digital Architecture' }}</p>
                    <p>{{ $providerSettings['company_subtitle'] ?? 'Pusat Pengembangan Sistem SaaS' }}</p>
                    @if (!empty($providerSettings['company_email']))
                        <p>Email: {{ $providerSettings['company_email'] }}</p>
                    @endif
                    @if (!empty($providerSettings['company_phone']))
                        <p>Telp/WA: {{ $providerSettings['company_phone'] }}</p>
                    @endif
                    @if (!empty($providerSettings['company_address']))
                        <p>{{ $providerSettings['company_address'] }}</p>
                    @endif
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

    <div class="payment-box">
        <div class="payment-title">Instruksi Pembayaran</div>
        <p class="payment-intro">Tagihan ini belum dibayar. Untuk mengaktifkan lisensi dan mendapatkan Token enkripsi perangkat Anda, silakan lakukan pembayaran penuh sebelum batas waktu yang ditentukan ({{ $invoice->due_date ? $invoice->due_date->translatedFormat('d F Y') : '-' }}) melalui metode transfer bank di bawah ini:</p>
        
        <div class="payment-details">
            <table>
                <tr>
                    <td class="pay-label">Bank Tujuan</td>
                    <td class="pay-val">{{ $providerSettings['bank_name'] ?? 'Bank Mandiri' }}</td>
                </tr>
                <tr>
                    <td class="pay-label">Nomor Rekening / Virtual Account</td>
                    <td class="pay-val" style="letter-spacing: 1px; font-family: monospace; font-size: 13px;">{{ $providerSettings['bank_account_number'] ?? '8899-0022-1133' }}</td>
                </tr>
                <tr>
                    <td class="pay-label">Atas Nama</td>
                    <td class="pay-val">{{ $providerSettings['bank_account_holder'] ?? 'PT Wirodev Digital Architecture' }}</td>
                </tr>
                <tr>
                    <td class="pay-label">Jumlah Tagihan</td>
                    <td class="pay-val" style="color: #0369a1; font-size: 14px;">Rp{{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
                </tr>
            </table>
        </div>

        <div class="payment-footer">
            Setelah melakukan transfer, silakan unggah bukti pembayaran melalui Dasbor Web Back Office Anda atau hubungi tim administrasi kami. Token Lisensi akan otomatis terbit di dasbor Anda setelah pembayaran diverifikasi.
        </div>
    </div>

    <div class="footer">
        Dokumen ini diterbitkan secara otomatis - {{ $invoice->invoice_number }}
    </div>
</body>
</html>
