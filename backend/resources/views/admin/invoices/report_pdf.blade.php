<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Laporan Rekapitulasi Invoice</title>
    <style>
        body {
            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
            font-size: 11px;
            color: #333333;
            line-height: 1.4;
            margin: 0;
            padding: 20px;
        }
        .header-table {
            width: 100%;
            border-bottom: 2px solid #144683;
            padding-bottom: 12px;
            margin-bottom: 20px;
        }
        .header-title {
            font-size: 18px;
            font-weight: bold;
            color: #144683;
            margin: 0;
        }
        .header-subtitle {
            font-size: 11px;
            color: #666;
            margin-top: 4px;
        }
        .summary-box {
            background-color: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            padding: 12px;
            margin-bottom: 20px;
        }
        .summary-table {
            width: 100%;
        }
        .summary-table td {
            padding: 4px 8px;
            font-size: 11px;
        }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        .data-table th {
            background-color: #144683;
            color: #ffffff;
            font-weight: bold;
            text-align: left;
            padding: 8px 6px;
            font-size: 10px;
            text-transform: uppercase;
        }
        .data-table td {
            padding: 8px 6px;
            border-bottom: 1px solid #e2e8f0;
            font-size: 10px;
        }
        .data-table tr:nth-child(even) td {
            background-color: #fcfcfd;
        }
        .badge {
            display: inline-block;
            padding: 2px 6px;
            font-size: 9px;
            font-weight: bold;
            border-radius: 4px;
            text-transform: uppercase;
        }
        .badge-paid { background-color: #d1fae5; color: #065f46; }
        .badge-unpaid { background-color: #fee2e2; color: #991b1b; }
        .badge-billed { background-color: #fef3c7; color: #92400e; }
        .badge-cancelled { background-color: #f3f4f6; color: #4b5563; }
        .footer {
            margin-top: 30px;
            border-top: 1px solid #e2e8f0;
            padding-top: 10px;
            font-size: 9px;
            color: #888;
            text-align: right;
        }
    </style>
</head>
<body>
    <table class="header-table">
        <tr>
            <td>
                <h1 class="header-title">LAPORAN REKAPITULASI INVOICE</h1>
                <div class="header-subtitle">{{ $providerSettings['company_name'] }} &bull; {{ $providerSettings['company_subtitle'] }}</div>
            </td>
            <td style="text-align: right; vertical-align: bottom;">
                <div><strong>Periode:</strong> {{ \Carbon\Carbon::parse($fromDate)->format('d/m/Y') }} &ndash; {{ \Carbon\Carbon::parse($toDate)->format('d/m/Y') }}</div>
                <div style="font-size: 10px; color: #666;">Dicetak pada: {{ now()->format('d/m/Y H:i') }} WIB</div>
            </td>
        </tr>
    </table>

    <div class="summary-box">
        <table class="summary-table">
            <tr>
                <td style="width: 25%;"><strong>Total Omset Lunas (PAID):</strong></td>
                <td style="width: 25%; color: #065f46; font-size: 13px; font-weight: bold;">Rp {{ number_format($totalRevenue, 0, ',', '.') }}</td>
                <td style="width: 25%;"><strong>Total Faktur Terbit:</strong></td>
                <td style="width: 25%; font-size: 13px; font-weight: bold;">Rp {{ number_format($totalInvoiced, 0, ',', '.') }}</td>
            </tr>
            <tr>
                <td><strong>Jumlah Invoice Lunas:</strong></td>
                <td>{{ $countPaid }} transaksi</td>
                <td><strong>Total Semua Invoice:</strong></td>
                <td>{{ $countTotal }} transaksi</td>
            </tr>
        </table>
    </div>

    <table class="data-table">
        <thead>
            <tr>
                <th style="width: 5%;">No</th>
                <th style="width: 20%;">No. Invoice</th>
                <th style="width: 25%;">Tenant</th>
                <th style="width: 15%;">Tanggal</th>
                <th style="width: 15%;">Nominal</th>
                <th style="width: 20%;">Status</th>
            </tr>
        </thead>
        <tbody>
            @forelse($invoices as $index => $inv)
                <tr>
                    <td>{{ $index + 1 }}</td>
                    <td style="font-family: monospace; font-weight: bold;">{{ $inv->invoice_number }}</td>
                    <td>{{ $inv->tenant?->name ?? '-' }}</td>
                    <td>{{ $inv->created_at ? $inv->created_at->format('d/m/Y') : '-' }}</td>
                    <td style="font-weight: bold;">Rp {{ number_format($inv->total_amount, 0, ',', '.') }}</td>
                    <td>
                        <span class="badge badge-{{ strtolower($inv->status->value) }}">
                            {{ $inv->status->label() }}
                        </span>
                    </td>
                </tr>
            @empty
                <tr>
                    <td colspan="6" style="text-align: center; padding: 20px; color: #888;">
                        Tidak ada transaksi invoice pada periode ini.
                    </td>
                </tr>
            @endforelse
        </tbody>
    </table>

    <div class="footer">
        Dokumen ini dibuat otomatis oleh Sistem SaaS POS &bull; Halaman 1
    </div>
</body>
</html>
