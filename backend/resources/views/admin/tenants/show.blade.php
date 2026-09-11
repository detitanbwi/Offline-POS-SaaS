@extends('admin.layouts.app')
@section('title', 'Detail Pelanggan — ' . ($tenant->name ?? $tenant->store_name) . ' - Kasir Pro Admin')
@section('header_title', $tenant->name ?? $tenant->store_name)

@section('content')
<div class="grid grid-2 mb-4">
    {{-- Card 1: Informasi Pelanggan & Akun Pemilik --}}
    <div class="card">
        <div class="card-header flex justify-between items-center">
            <div>
                <h3 class="card-title">Informasi Pelanggan</h3>
                <div style="margin-top: 4px;">
                    <span class="badge {{ $tenant->customer_type === 'company' ? 'badge-info' : 'badge-warning' }}">
                        {{ $tenant->customer_type_label }}
                    </span>
                    <span class="badge {{ $tenant->status->badgeClass() }}">{{ $tenant->status->label() }}</span>
                </div>
            </div>
            @can('tenants.create')
                <a href="{{ route('admin.tenants.create') }}?customer_id={{ $tenant->id }}" class="btn btn-primary btn-xs">
                    + Tambah Lisensi
                </a>
            @endcan
        </div>
        <div class="detail-grid">
            <div class="detail-label">Nama Pelanggan / Badan Usaha</div>
            <div class="detail-value font-semibold">{{ $tenant->name }}</div>
            <div class="detail-label">Tipe Pelanggan</div>
            <div class="detail-value">{{ $tenant->customer_type_label }}</div>
            @if($tenant->tax_number)
                <div class="detail-label">NPWP</div>
                <div class="detail-value font-mono">{{ $tenant->tax_number }}</div>
            @endif
            <div class="detail-label">Nama Toko / Outlet</div>
            <div class="detail-value">{{ $tenant->store_name ?? '-' }}</div>
            <div class="detail-label">Pemilik / PIC</div>
            <div class="detail-value">{{ $tenant->owner_name }}</div>
            <div class="detail-label">Email Login Kasir</div>
            <div class="detail-value font-mono">{{ $tenant->email }}</div>
            <div class="detail-label">No. Telepon / WA</div>
            <div class="detail-value">{{ $tenant->phone ?? '-' }}</div>
            <div class="detail-label">Alamat Toko</div>
            <div class="detail-value">{{ $tenant->store_address ?? '-' }}</div>
            @if($tenant->city)
                <div class="detail-label">Kota / Kode Pos</div>
                <div class="detail-value">{{ $tenant->city }} {{ $tenant->postal_code ? '('.$tenant->postal_code.')' : '' }}</div>
            @endif
            <div class="detail-label">Terdaftar Sejak</div>
            <div class="detail-value">{{ $tenant->created_at->format('d F Y, H:i') }}</div>
        </div>
        <div class="flex gap-3 mt-4 flex-wrap">
            @can('tenants.edit')
                <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-sm">Edit Data Pelanggan</a>
            @endcan
            @can('tenants.suspend')
                @if ($tenant->status->value === 'active')
                    <form method="POST" action="{{ route('admin.tenants.suspend', $tenant) }}" onsubmit="return confirm('Tangguhkan pelanggan ini? Akun kasir tidak akan bisa login atau aktivasi.')">
                        @csrf
                        <button type="submit" class="btn btn-warning btn-sm">Tangguhkan</button>
                    </form>
                @elseif ($tenant->status->value === 'suspended')
                    <form method="POST" action="{{ route('admin.tenants.reactivate', $tenant) }}" onsubmit="return confirm('Aktifkan kembali pelanggan ini?')">
                        @csrf
                        <button type="submit" class="btn btn-success btn-sm">Aktifkan Kembali</button>
                    </form>
                @endif
            @endcan
            @can('tenants.delete')
                <form method="POST" action="{{ route('admin.tenants.destroy', $tenant) }}" onsubmit="return confirm('Pindahkan {{ $tenant->name }} ke tempat sampah (Soft Delete)?')">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="btn btn-danger btn-sm">Hapus</button>
                </form>
            @endcan
        </div>
    </div>

    {{-- Card 2: Ringkasan Status Langganan & Kuota Perangkat --}}
    @php
        $activeSub = $tenant->subscriptions->where('status', \App\Enums\SubscriptionStatus::ACTIVE)->first();
        $totalTokens = $tenant->invoices->where('status', \App\Enums\InvoiceStatus::PAID)->flatMap->subscriptions->flatMap->licenseTokens->count();
        $activeTokens = $tenant->invoices->where('status', \App\Enums\InvoiceStatus::PAID)->flatMap->subscriptions->flatMap->licenseTokens->where('status', \App\Enums\TokenStatus::ACTIVE)->count();
        $availableTokens = $tenant->invoices->where('status', \App\Enums\InvoiceStatus::PAID)->flatMap->subscriptions->flatMap->licenseTokens->where('status', \App\Enums\TokenStatus::AVAILABLE)->count();
    @endphp
    <div class="card flex flex-col justify-between">
        <div>
            <div class="card-header">
                <h3 class="card-title">Ringkasan Kuota & Lisensi</h3>
                @if ($activeSub)
                    <span class="badge {{ $activeSub->status->badgeClass() }}">{{ $activeSub->status->label() }}</span>
                @else
                    <span class="badge badge-secondary">Belum Berlangganan</span>
                @endif
            </div>

            <div class="detail-grid">
                <div class="detail-label">Paket Aktif</div>
                <div class="detail-value font-semibold text-primary">
                    {{ $activeSub ? $activeSub->package_name : 'Tidak Ada Paket Aktif' }}
                </div>
                <div class="detail-label">Masa Berlaku</div>
                <div class="detail-value">
                    @if ($activeSub && $activeSub->expiry_date)
                        {{ $activeSub->expiry_date->format('d F Y') }}
                        @if ($activeSub->remainingDays() > 0)
                            <span class="text-sm text-success font-medium">({{ $activeSub->remainingDays() }} hari tersisa)</span>
                        @else
                            <span class="text-sm text-danger font-medium">(Kedaluwarsa)</span>
                        @endif
                    @else
                        -
                    @endif
                </div>
                <div class="detail-label">Kuota Perangkat Kasir</div>
                <div class="detail-value">
                    <span class="font-bold text-lg" style="color: var(--primary);">{{ $activeTokens }}</span>
                    <span class="text-secondary">/ {{ $totalTokens }} perangkat terikat</span>
                    @if ($availableTokens > 0)
                        <span class="badge badge-success" style="margin-left: 8px; font-size: 11px;">
                            {{ $availableTokens }} token siap dipakai
                        </span>
                    @endif
                </div>
                <div class="detail-label">Total Invoice</div>
                <div class="detail-value">
                    {{ $tenant->invoices->count() }} tagihan 
                    ({{ $tenant->invoices->where('status', \App\Enums\InvoiceStatus::PAID)->count() }} Lunas, 
                     {{ $tenant->invoices->where('status', \App\Enums\InvoiceStatus::UNPAID)->count() }} Belum Lunas)
                </div>
            </div>
        </div>

        <div class="mt-4 pt-4" style="border-top: 1px solid var(--divider);">
            @can('invoices.create')
                <a href="{{ route('admin.invoices.create', ['tenant_id' => $tenant->id]) }}" class="btn btn-primary btn-sm" style="width: 100%; text-align: center; justify-content: center;">
                    + Buat Invoice Baru (Tambah Perangkat / Perpanjangan)
                </a>
            @endcan
        </div>
    </div>
</div>

{{-- Card 3: Riwayat Tagihan & Pembelian Lisensi --}}
<div class="card mb-4">
    <div class="card-header flex justify-between items-center flex-wrap gap-2">
        <div>
            <h3 class="card-title">Riwayat Tagihan & Pembelian Lisensi</h3>
            <p class="text-sm text-secondary" style="margin: 2px 0 0 0;">
                Semua token lisensi dan kuota perangkat dikelola transparan di dalam setiap faktur invoice.
            </p>
        </div>
        @can('invoices.create')
            <a href="{{ route('admin.invoices.create', ['tenant_id' => $tenant->id]) }}" class="btn btn-outline btn-xs">
                + Tambah Tagihan
            </a>
        @endcan
    </div>

    @if ($tenant->invoices->isEmpty())
        <div style="padding: 32px 16px; text-align: center; color: var(--text-secondary);">
            <p style="font-size: 14px; margin-bottom: 12px;">Pelanggan ini belum memiliki catatan invoice tagihan.</p>
            @can('invoices.create')
                <a href="{{ route('admin.invoices.create', ['tenant_id' => $tenant->id]) }}" class="btn btn-primary btn-sm">
                    Buat Invoice Pertama
                </a>
            @endcan
        </div>
    @else
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>No. Invoice</th>
                        <th>Tanggal</th>
                        <th>Item Lisensi Terbeli</th>
                        <th>Total Tagihan</th>
                        <th>Status</th>
                        <th>Bukti Transfer</th>
                        <th>Token Lisensi</th>
                        <th>Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($tenant->invoices as $invoice)
                    @php
                        $invoiceTokensCount = $invoice->subscriptions->flatMap->licenseTokens->count();
                    @endphp
                    <tr>
                        <td>
                            <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => url()->current()]) }}" class="font-mono font-bold" style="color: var(--primary); text-decoration: none;">
                                {{ $invoice->invoice_number }}
                            </a>
                        </td>
                        <td>{{ $invoice->created_at->format('d M Y') }}</td>
                        <td>
                            @foreach ($invoice->items as $item)
                                <div style="font-size: 13px;">
                                    <strong>{{ $item->package_name }}</strong> 
                                    <span class="text-secondary">(x{{ $item->quantity }})</span>
                                    @if ($item->client_note)
                                        <span class="text-xs text-secondary" style="display: block;">{{ $item->client_note }}</span>
                                    @endif
                                </div>
                            @endforeach
                        </td>
                        <td class="font-semibold">
                            Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}
                        </td>
                        <td>
                            <span class="badge {{ $invoice->status->badgeClass() }}">
                                {{ $invoice->status->label() }}
                            </span>
                        </td>
                        <td>
                            @if ($invoice->payment_proof)
                                <a href="{{ $invoice->payment_proof_url }}" target="_blank" class="btn btn-outline btn-xs" style="text-decoration: none;">
                                    Lihat Bukti
                                </a>
                            @else
                                <span class="text-muted text-xs">-</span>
                            @endif
                        </td>
                        <td>
                            @if ($invoice->status->value === 'paid')
                                <span class="badge badge-success" style="font-size: 11px;">
                                    {{ $invoiceTokensCount }} Token Diterbitkan
                                </span>
                            @elseif ($invoice->status->value === 'unpaid')
                                <span class="badge badge-warning" style="font-size: 11px;">
                                    Menunggu Pembayaran
                                </span>
                            @else
                                <span class="badge badge-secondary" style="font-size: 11px;">
                                    Dibatalkan
                                </span>
                            @endif
                        </td>
                        <td>
                            <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => url()->current()]) }}" class="btn btn-outline btn-xs">
                                Buka Detail & Token &rarr;
                            </a>
                        </td>
                    </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</div>

{{-- Card 4: Perangkat Kasir Terdaftar (Registered Hardware Devices) --}}
@if ($tenant->devices->count() > 0)
<div class="card mb-4">
    <div class="card-header">
        <h3 class="card-title">Perangkat Kasir Terdaftar ({{ $tenant->devices->count() }})</h3>
        <p class="text-sm text-secondary" style="margin: 2px 0 0 0;">
            Daftar perangkat fisik kasir (Tablet / HP) yang telah mengaktifkan token lisensi pelanggan ini.
        </p>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Perangkat</th>
                    <th>Token Lisensi Terikat</th>
                    <th>Catatan Kasir</th>
                    <th>Aktivasi Pertama</th>
                    <th>Validasi Terakhir</th>
                    <th>Status Perangkat</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($tenant->devices as $device)
                <tr>
                    <td class="font-semibold">{{ $device->display_name }}</td>
                    <td>
                        @if ($device->licenseToken)
                            <a href="{{ route('admin.tokens.show', $device->licenseToken) }}" class="font-mono text-sm" style="color: var(--primary);">
                                {{ $device->licenseToken->token_key }}
                            </a>
                        @else
                            <span class="text-muted">-</span>
                        @endif
                    </td>
                    <td>{{ $device->licenseToken?->client_note ?? '-' }}</td>
                    <td class="text-sm">{{ $device->activated_at ? $device->activated_at->format('d M Y, H:i') : '-' }}</td>
                    <td class="text-sm">{{ $device->last_validated_at ? $device->last_validated_at->format('d M Y, H:i') : '-' }}</td>
                    <td>
                        <span class="badge {{ $device->status->badgeClass() }}">
                            {{ $device->status->label() }}
                        </span>
                    </td>
                    <td>
                        @if ($device->licenseToken)
                            <a href="{{ route('admin.tokens.show', $device->licenseToken) }}" class="btn btn-outline btn-xs">
                                Kelola Token
                            </a>
                        @endif
                    </td>
                </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
@endif

<div style="margin-top: 16px;">
    <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline btn-sm">&larr; Kembali ke Data Pelanggan</a>
</div>
@endsection
