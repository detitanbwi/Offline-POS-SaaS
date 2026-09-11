@extends('admin.layouts.app')
@section('title', 'Invoice ' . $invoice->invoice_number . ' - Kasir Pro Admin')
@section('header_title', 'Invoice ' . $invoice->invoice_number)

@section('content')
@php
    $resolvedBackUrl = $backUrl ?? (url()->previous() && url()->previous() !== url()->current() ? url()->previous() : route('admin.invoices.index'));
@endphp

<div class="mb-3 flex justify-between items-center flex-wrap gap-2">
    <a href="{{ $resolvedBackUrl }}" class="btn btn-outline btn-sm" onclick="if (window.history.length > 1 && document.referrer && !document.referrer.includes(window.location.pathname)) { window.history.back(); return false; }">
        &larr; Kembali
    </a>
    <div class="text-xs text-secondary">
        @if (str_contains($resolvedBackUrl, 'tenants'))
            <span>Tujuan Kembali: <strong>{{ $invoice->tenant->name ?? 'Detail Tenant' }}</strong></span>
        @elseif (str_contains($resolvedBackUrl, 'trash'))
            <span>Tujuan Kembali: <strong>Tempat Sampah</strong></span>
        @else
            <span>Tujuan Kembali: <strong>Daftar Invoice</strong></span>
        @endif
    </div>
</div>

@if ($invoice->trashed())
<div class="alert alert-danger mb-4 flex items-center justify-between flex-wrap gap-3" style="border-radius: 12px; padding: 16px;">
    <div>
        <strong>⚠️ Perhatian: Invoice ini berada di tempat sampah (Soft Deleted).</strong>
        <p class="text-xs text-secondary" style="margin: 4px 0 0 0;">Dihapus pada: {{ $invoice->deleted_at->format('d F Y, H:i') }}. Anda dapat memulihkannya kapan saja.</p>
    </div>
    @can('invoices.restore')
        <form method="POST" action="{{ route('admin.invoices.restore', $invoice->id) }}">
            @csrf
            <button type="submit" class="btn btn-success btn-sm">Pulihkan Invoice Ini</button>
        </form>
    @endcan
</div>
@endif

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
            <div class="detail-value">{{ $invoice->payment_method ? strtoupper(str_replace('_', ' ', $invoice->payment_method)) : '-' }}</div>
            <div class="detail-label">Bukti Transfer</div>
            <div class="detail-value">
                @if ($invoice->payment_proof)
                    <a href="{{ $invoice->payment_proof_url }}" target="_blank" class="btn btn-outline btn-xs" style="text-decoration: none;">
                        Lihat Bukti Transfer
                    </a>
                @else
                    <span class="text-muted">Belum ada bukti transfer</span>
                @endif
            </div>
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

{{-- Upload Bukti Transfer Card (If UNPAID) --}}
@if ($invoice->status->value === 'unpaid')
@can('invoices.upload_proof')
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Unggah Bukti Transfer</h3>
    </div>
    <div style="max-width: 600px;">
        <p style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px;">
            Unggah bukti transfer dari pelanggan. File bukti akan tersimpan untuk diperiksa sebelum dikonfirmasi LUNAS.
        </p>
        <form action="{{ route('admin.invoices.upload-proof', $invoice) }}" method="POST" enctype="multipart/form-data" class="flex gap-3 items-center flex-wrap" onsubmit="return confirm('Apakah Anda yakin ingin mengunggah bukti transfer ini?')">
            @csrf
            <input type="file" name="payment_proof" class="form-control" style="max-width: 320px;" accept="image/jpeg,image/png,image/jpg,application/pdf" required>
            <button type="submit" class="btn btn-primary btn-sm">Upload Bukti Transfer</button>
        </form>
        @error('payment_proof')
            <div class="form-error mt-2">{{ $message }}</div>
        @enderror
    </div>
</div>
@endcan
@endif

{{-- Preview Bukti Transfer --}}
@if ($invoice->payment_proof)
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Preview Bukti Transfer</h3>
    </div>
    <div>
        @if (Str::endsWith(strtolower($invoice->payment_proof), '.pdf'))
            <a href="{{ $invoice->payment_proof_url }}" target="_blank" class="btn btn-outline btn-sm">Buka Dokumen PDF Bukti Transfer</a>
        @else
            <a href="{{ $invoice->payment_proof_url }}" target="_blank">
                <img src="{{ $invoice->payment_proof_url }}" alt="Bukti Transfer" style="max-width: 400px; max-height: 400px; border-radius: 12px; border: 1px solid var(--divider); object-fit: contain;">
            </a>
        @endif
    </div>
</div>
@endif

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
        <h3 class="card-title">Aksi Admin & Approval</h3>
    </div>
    <div class="flex gap-3 flex-wrap items-center">
        @if ($invoice->status->value === 'unpaid')
            @can('invoices.mark_paid')
            <form id="approvalForm" method="POST" action="{{ route('admin.invoices.mark-paid', $invoice) }}" enctype="multipart/form-data" style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
                @csrf
                <label style="font-size: 13px; font-weight: 500;">Metode Bayar:</label>
                <select name="payment_method" id="payment_method_select" style="padding: 8px 12px; border-radius: 8px; border: 1px solid var(--divider); font-size: 13px;">
                    <option value="bank_transfer" {{ $invoice->payment_method === 'bank_transfer' ? 'selected' : '' }}>Transfer Bank</option>
                    <option value="cash" {{ $invoice->payment_method === 'cash' ? 'selected' : '' }}>Tunai</option>
                    <option value="qris" {{ $invoice->payment_method === 'qris' ? 'selected' : '' }}>QRIS</option>
                    <option value="debit" {{ $invoice->payment_method === 'debit' ? 'selected' : '' }}>Debit</option>
                    <option value="credit" {{ $invoice->payment_method === 'credit' ? 'selected' : '' }}>Kartu Kredit</option>
                </select>
                <button type="button" onclick="showApprovalModal()" class="btn btn-success btn-sm">Approve & Mark as Paid (Lunas)</button>
            </form>
            @endcan

            @can('invoices.cancel')
            <form method="POST" action="{{ route('admin.invoices.cancel', $invoice) }}" style="display: inline;" onsubmit="return confirm('Apakah Anda yakin ingin membatalkan invoice {{ $invoice->invoice_number }}?')">
                @csrf
                <button type="submit" class="btn btn-danger btn-sm">Batalkan Invoice</button>
            </form>
            @endcan
        @endif

        @if ($invoice->trashed())
            @can('invoices.restore')
            <form method="POST" action="{{ route('admin.invoices.restore', $invoice->id) }}" style="display: inline;" onsubmit="return confirm('Pulihkan invoice {{ $invoice->invoice_number }}?')">
                @csrf
                <button type="submit" class="btn btn-success btn-sm">Pulihkan Invoice (Restore)</button>
            </form>
            @endcan
        @else
            @can('invoices.delete')
            <form method="POST" action="{{ route('admin.invoices.destroy', $invoice) }}" style="display: inline;" onsubmit="return confirm('Pindahkan invoice {{ $invoice->invoice_number }} ke tempat sampah (Soft Delete)?')">
                @csrf
                @method('DELETE')
                <button type="submit" class="btn btn-danger btn-sm">Hapus Invoice</button>
            </form>
            @endcan
        @endif

        @if ($invoice->status->value === 'unpaid')
            <a href="{{ route('admin.invoices.download-pdf', $invoice) }}" class="btn btn-outline btn-sm">Download PDF Faktur Tagihan (Belum Lunas)</a>
        @else
            <a href="{{ route('admin.invoices.download-pdf', $invoice) }}" class="btn btn-outline btn-sm">Download PDF Faktur Lunas (Paid)</a>
        @endif
        <a href="{{ $resolvedBackUrl }}" class="btn btn-outline btn-sm" onclick="if (window.history.length > 1 && document.referrer && !document.referrer.includes(window.location.pathname)) { window.history.back(); return false; }">Kembali</a>
    </div>
</div>

{{-- Approval Modal Confirmation --}}
@if ($invoice->status->value === 'unpaid')
<div id="approvalModal" style="display: none; position: fixed; inset: 0; background: rgba(15, 23, 42, 0.6); backdrop-filter: blur(4px); z-index: 9999; align-items: center; justify-content: center; padding: 20px;">
    <div style="background: white; border-radius: 16px; width: 100%; max-width: 480px; padding: 24px; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);">
        <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 16px;">
            <div style="background: #dcfce7; border-radius: 50%; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; color: #16a34a; font-size: 24px;">✓</div>
            <div>
                <h4 style="font-size: 18px; font-weight: 700; color: #0f172a; margin: 0;">Konfirmasi Approval Pelunasan</h4>
                <p style="font-size: 13px; color: #64748b; margin: 2px 0 0 0;">Invoice {{ $invoice->invoice_number }}</p>
            </div>
        </div>
        <p style="font-size: 14px; color: #334155; line-height: 1.5; margin-bottom: 16px;">
            Apakah Anda yakin ingin menyetujui pembayaran invoice ini? Status akan otomatis berubah menjadi <strong>LUNAS (PAID)</strong> dan <strong>Token Lisensi</strong> akan diterbitkan untuk tenant <strong>{{ $invoice->tenant->name }}</strong>.
        </p>
        <div style="background: #f8fafc; border-radius: 8px; padding: 12px; margin-bottom: 20px; font-size: 13px; border: 1px solid #e2e8f0;">
            <div><strong>Total Tagihan:</strong> Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</div>
            <div style="margin-top: 4px;"><strong>Bukti Transfer:</strong> {{ $invoice->payment_proof ? 'Sudah Diunggah ✓' : 'Belum Diunggah' }}</div>
        </div>
        <div style="display: flex; justify-content: flex-end; gap: 12px;">
            <button type="button" onclick="hideApprovalModal()" class="btn btn-outline btn-sm">Batal</button>
            <button type="button" onclick="submitApprovalForm()" class="btn btn-success btn-sm">Ya, Setujui & Lunaskan</button>
        </div>
    </div>
</div>

<script>
    function showApprovalModal() {
        document.getElementById('approvalModal').style.display = 'flex';
    }
    function hideApprovalModal() {
        document.getElementById('approvalModal').style.display = 'none';
    }
    function submitApprovalForm() {
        document.getElementById('approvalForm').submit();
    }
</script>
@endif

{{-- Tokens (only if PAID) --}}
@if ($invoice->status->value === 'paid')
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Token Lisensi yang Diterbitkan (Rasio 1 Token = 1 Perangkat Kasir)</h3>
        <p class="text-sm text-secondary" style="margin: 2px 0 0 0;">
            Setiap token lisensi di bawah ini terbit otomatis dari pembayaran invoice ini dan dapat diaktifkan pada 1 unit mesin/tablet kasir toko.
        </p>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Catatan Kasir</th>
                    <th>Token Key</th>
                    <th>Paket & Masa Berlaku</th>
                    <th>Status Token</th>
                    <th>Perangkat Terikat</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($invoice->subscriptions as $sub)
                    @foreach ($sub->licenseTokens as $token)
                    <tr>
                        <td style="font-weight: 600;">{{ $token->client_note ?? $sub->client_note ?? 'Mesin Kasir #' . $loop->iteration }}</td>
                        <td>
                            <div class="flex items-center gap-2">
                                <span class="token-display font-mono" style="color: var(--primary); font-weight: 700; font-size: 13px;">{{ $token->token_key }}</span>
                                <button type="button" onclick="navigator.clipboard.writeText('{{ $token->token_key }}'); alert('Token disalin: {{ $token->token_key }}');" class="btn btn-outline btn-xs" title="Salin Token">
                                    Salin
                                </button>
                            </div>
                        </td>
                        <td>
                            <div style="font-size: 13px; font-weight: 600;">{{ $sub->package_name }}</div>
                            <div class="text-xs text-secondary">
                                s/d {{ $sub->expiry_date ? $sub->expiry_date->format('d M Y') : '-' }}
                                @if ($sub->remainingDays() > 0)
                                    <span class="text-success">({{ $sub->remainingDays() }} hari)</span>
                                @else
                                    <span class="text-danger">(Kedaluwarsa)</span>
                                @endif
                            </div>
                        </td>
                        <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                        <td>
                            @if ($token->device)
                                <div style="font-size: 13px; font-weight: 600;">{{ $token->device->display_name }}</div>
                                <div class="text-xs text-secondary font-mono">
                                    ID: {{ substr($token->device->fingerprint_hash, 0, 10) }}...
                                </div>
                            @else
                                <span class="badge badge-success" style="font-size: 11px;">
                                    Belum Terikat (Tersedia)
                                </span>
                            @endif
                        </td>
                        <td>
                            <div class="flex gap-2 items-center flex-wrap">
                                <a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a>
                                @if ($token->device && $token->status->value === 'active')
                                    @can('tokens.reset_device')
                                    <form method="POST" action="{{ route('admin.tokens.reset-device', $token) }}" onsubmit="return confirm('Reset perangkat dari token {{ $token->token_key }}? Gunakan ini jika tablet kasir rusak/diganti.')" style="display: inline;">
                                        @csrf
                                        <button type="submit" class="btn btn-warning btn-xs">Reset Mesin</button>
                                    </form>
                                    @endcan
                                @endif
                            </div>
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
