@extends('admin.layouts.app')
@section('title', "Invoice {{ $invoice->invoice_number }} — POS SaaS Admin")
@section('header_title', "Invoice {{ $invoice->invoice_number }}")

@section('content')
<div class="grid grid-2">
    {{-- Invoice Info --}}
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Detail Invoice</h3>
            <span class="badge {{ $invoice->status->badgeClass() }}" style="font-size: 13px; padding: 6px 14px;">{{ $invoice->status->label() }}</span>
        </div>
        <div class="detail-grid">
            <div class="detail-label">No. Invoice</div>
            <div class="detail-value font-mono" style="font-weight: 600;">{{ $invoice->invoice_number }}</div>
            <div class="detail-label">Tanggal</div>
            <div class="detail-value">{{ $invoice->created_at->format('d F Y, H:i') }}</div>
            <div class="detail-label">Jatuh Tempo</div>
            <div class="detail-value">{{ $invoice->due_date?->format('d F Y') ?? '-' }}</div>
            <div class="detail-label">Dibayar Pada</div>
            <div class="detail-value">{{ $invoice->paid_at?->format('d F Y, H:i') ?? '-' }}</div>
            <div class="detail-label">Metode Bayar</div>
            <div class="detail-value">{{ $invoice->payment_method ?? '-' }}</div>
        </div>
    </div>

    {{-- Tenant Info --}}
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Data Tenant</h3>
        </div>
        <div class="detail-grid">
            <div class="detail-label">Nama</div>
            <div class="detail-value">{{ $invoice->tenant->name }}</div>
            <div class="detail-label">Pemilik</div>
            <div class="detail-value">{{ $invoice->tenant->owner_name }}</div>
            <div class="detail-label">Email</div>
            <div class="detail-value">{{ $invoice->tenant->email }}</div>
            <div class="detail-label">Telepon</div>
            <div class="detail-value">{{ $invoice->tenant->phone ?? '-' }}</div>
            <div class="detail-label">Toko</div>
            <div class="detail-value">{{ $invoice->tenant->store_name ?? '-' }}</div>
        </div>
    </div>
</div>

{{-- Invoice Items --}}
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Rincian Transaksi Keranjang Lisensi</h3>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Item Paket Lisensi</th>
                    <th>Catatan Mesin Klien</th>
                    <th>Durasi</th>
                    <th>Qty</th>
                    <th>Harga Satuan</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($invoice->items as $item)
                <tr>
                    <td style="font-weight: 600;">{{ $item->package_name }}</td>
                    <td>{{ $item->client_note ?? '-' }}</td>
                    <td>{{ $item->duration_days }} hari</td>
                    <td>{{ $item->quantity }}</td>
                    <td>Rp {{ number_format($item->unit_price, 0, ',', '.') }}</td>
                    <td style="font-weight: 600;">Rp {{ number_format($item->total_price, 0, ',', '.') }}</td>
                </tr>
                @endforeach
            </tbody>
            <tfoot>
                <tr>
                    <td colspan="5" style="text-align: right; font-weight: 600;">GRAND TOTAL PEMBAYARAN</td>
                    <td style="font-weight: 700; font-size: 16px; color: var(--primary);">Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
                </tr>
            </tfoot>
        </table>
    </div>
</div>

{{-- Actions --}}
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Aksi</h3>
    </div>
    <div class="flex gap-3 flex-wrap">
        @if ($invoice->status->value === 'unpaid')
            <form method="POST" action="{{ route('admin.invoices.mark-paid', $invoice) }}" style="display: inline;" onsubmit="return confirm('Konfirmasi pembayaran invoice ini?')">
                @csrf
                <select name="payment_method" style="padding: 8px 12px; border-radius: 8px; border: 1px solid var(--divider); font-size: 13px; margin-right: 4px;">
                    <option value="bank_transfer">Transfer Bank (Mandiri)</option>
                    <option value="cash">Tunai</option>
                    <option value="qris">QRIS</option>
                    <option value="debit">Debit</option>
                    <option value="credit">Kartu Kredit</option>
                </select>
                <button type="submit" class="btn btn-success btn-sm">✓ Konfirmasi Pembayaran</button>
            </form>
            <form method="POST" action="{{ route('admin.invoices.cancel', $invoice) }}" style="display: inline;" onsubmit="return confirm('Batalkan invoice ini?')">
                @csrf
                <button type="submit" class="btn btn-danger btn-sm">✕ Batalkan Invoice</button>
            </form>
        @endif
        <a href="{{ route('admin.invoices.download-pdf', $invoice) }}" class="btn btn-outline btn-sm">⬇ Download PDF Faktur</a>
        <a href="{{ route('admin.invoices.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
    </div>
</div>

{{-- Tokens (only if PAID) --}}
@if ($invoice->status->value === 'paid')
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Token Lisensi yang Diterbitkan (Rasio 1 Token = 1 Perangkat)</h3>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Catatan Mesin Klien</th>
                    <th>Token Key</th>
                    <th>Paket</th>
                    <th>Status</th>
                    <th>Perangkat Terikat</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($invoice->subscriptions as $sub)
                    @foreach ($sub->licenseTokens as $token)
                    <tr>
                        <td style="font-weight: 600;">{{ $token->client_note ?? $sub->client_note ?? '-' }}</td>
                        <td><span class="token-display font-mono" style="color: var(--primary); font-weight: 700;">{{ $token->token_key }}</span></td>
                        <td>{{ $sub->package_name }}</td>
                        <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                        <td>{{ $token->device?->display_name ?? 'Belum terikat' }}</td>
                        <td>
                            <a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a>
                        </td>
                    </tr>
                    @endforeach
                @endforeach
            </tbody>
        </table>
    </div>
</div>
@endif
@endsection
