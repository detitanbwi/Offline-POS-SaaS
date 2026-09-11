@extends('admin.layouts.app')
@section('title', 'Pusat Pemulihan Data (Tempat Sampah) - Kasir Pro Admin')
@section('header_title', 'Tempat Sampah & Pemulihan Data')

@section('content')
{{-- Stats Summary --}}
<div class="grid grid-2 mb-4">
    <div class="card" style="border-left: 4px solid var(--primary);">
        <div style="display: flex; align-items: center; justify-content: space-between;">
            <div>
                <span class="text-xs text-secondary font-semibold uppercase tracking-wider">Tenant / Toko Terhapus</span>
                <div style="font-size: 28px; font-weight: 700; color: var(--primary); margin-top: 4px;">{{ $tenantCount }}</div>
                <p class="text-xs text-secondary mt-1">Data toko dan pemilik yang berada di tempat sampah.</p>
            </div>
            <div style="background: var(--primary-container); border-radius: 12px; padding: 12px; color: var(--primary);">
                <svg width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
            </div>
        </div>
    </div>

    <div class="card" style="border-left: 4px solid var(--secondary);">
        <div style="display: flex; align-items: center; justify-content: space-between;">
            <div>
                <span class="text-xs text-secondary font-semibold uppercase tracking-wider">Invoice Tagihan Terhapus</span>
                <div style="font-size: 28px; font-weight: 700; color: var(--secondary); margin-top: 4px;">{{ $invoiceCount }}</div>
                <p class="text-xs text-secondary mt-1">Faktur tagihan lisensi yang berada di tempat sampah.</p>
            </div>
            <div style="background: var(--secondary-container); border-radius: 12px; padding: 12px; color: var(--secondary);">
                <svg width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
            </div>
        </div>
    </div>
</div>

{{-- Main Card with Tabs --}}
<div class="card">
    <div class="card-header flex justify-between items-center flex-wrap gap-3" style="border-bottom: 1px solid var(--divider); padding-bottom: 16px;">
        <div class="flex gap-2">
            <a href="{{ route('admin.trash.index', ['tab' => 'tenants']) }}" 
               class="btn {{ $tab === 'tenants' ? 'btn-primary' : 'btn-outline' }} btn-sm" style="display: flex; align-items: center; gap: 8px;">
                <span>🏢 Tenant Terhapus</span>
                <span class="badge {{ $tab === 'tenants' ? 'badge-secondary' : '' }}" style="background: rgba(255,255,255,0.2); font-size: 11px;">{{ $tenantCount }}</span>
            </a>
            <a href="{{ route('admin.trash.index', ['tab' => 'invoices']) }}" 
               class="btn {{ $tab === 'invoices' ? 'btn-primary' : 'btn-outline' }} btn-sm" style="display: flex; align-items: center; gap: 8px;">
                <span>🧾 Invoice Terhapus</span>
                <span class="badge {{ $tab === 'invoices' ? 'badge-secondary' : '' }}" style="background: rgba(255,255,255,0.2); font-size: 11px;">{{ $invoiceCount }}</span>
            </a>
        </div>
        <div>
            <form method="GET" action="{{ route('admin.trash.index') }}" style="display: flex; gap: 8px;">
                <input type="hidden" name="tab" value="{{ $tab }}">
                <input type="text" name="search" class="form-control" style="max-width: 260px;" placeholder="Cari data terhapus..." value="{{ $search }}">
                <button type="submit" class="btn btn-outline btn-sm">Cari</button>
                @if ($search !== '')
                    <a href="{{ route('admin.trash.index', ['tab' => $tab]) }}" class="btn btn-outline btn-sm">Reset</a>
                @endif
            </form>
        </div>
    </div>

    @if ($tab === 'tenants')
        {{-- Tab 1: Trashed Tenants --}}
        <div class="table-responsive" style="margin-top: 16px;">
            <table class="table">
                <thead>
                    <tr>
                        <th>Nama Tenant / Toko</th>
                        <th>Pemilik Akun</th>
                        <th>Email</th>
                        <th>Status Asli</th>
                        <th>Tanggal Dihapus</th>
                        <th>Aksi Pemulihan</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($trashedTenants as $tenant)
                    <tr>
                        <td>
                            <div class="font-semibold" style="color: var(--text-primary);">{{ $tenant->store_name ?? $tenant->name }}</div>
                            <div class="text-xs text-secondary">{{ $tenant->name }}</div>
                        </td>
                        <td>{{ $tenant->owner_name }}</td>
                        <td class="font-mono text-sm">{{ $tenant->email }}</td>
                        <td>
                            <span class="badge badge-danger">Terhapus (Sampah)</span>
                        </td>
                        <td class="text-sm">
                            <span style="font-weight: 500;">{{ $tenant->deleted_at->format('d M Y, H:i') }}</span>
                            <span class="text-xs text-secondary" style="display: block;">{{ $tenant->deleted_at->diffForHumans() }}</span>
                        </td>
                        <td>
                            @can('tenants.restore')
                            <form method="POST" action="{{ route('admin.tenants.restore', $tenant->id) }}" onsubmit="return confirm('Apakah Anda yakin ingin memulihkan tenant {{ $tenant->name }}? Toko dan lisensi terkait akan kembali aktif.')">
                                @csrf
                                <button type="submit" class="btn btn-success btn-xs" style="display: flex; align-items: center; gap: 4px;">
                                    <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                                    Pulihkan Tenant
                                </button>
                            </form>
                            @endcan
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 48px; color: var(--text-secondary);">
                            <div style="font-size: 32px; margin-bottom: 8px;">🗑️</div>
                            <p style="font-weight: 500; font-size: 15px;">Tempat sampah tenant kosong.</p>
                            <span class="text-xs text-secondary">Tidak ada data toko atau tenant yang dihapus.</span>
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        <div class="pagination mt-4">{{ $trashedTenants->links() }}</div>

    @else
        {{-- Tab 2: Trashed Invoices --}}
        <div class="table-responsive" style="margin-top: 16px;">
            <table class="table">
                <thead>
                    <tr>
                        <th>No. Invoice</th>
                        <th>Tenant / Toko</th>
                        <th>Total Tagihan</th>
                        <th>Status Tagihan</th>
                        <th>Tanggal Dihapus</th>
                        <th>Aksi Pemulihan</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($trashedInvoices as $invoice)
                    <tr>
                        <td>
                            <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => request()->fullUrl()]) }}" class="font-mono font-bold" style="color: var(--primary); text-decoration: none;">
                                {{ $invoice->invoice_number }}
                            </a>
                        </td>
                        <td>
                            <div class="font-semibold">{{ $invoice->tenant?->store_name ?? $invoice->tenant?->name ?? 'Tenant Dihapus' }}</div>
                            <div class="text-xs text-secondary">{{ $invoice->tenant?->email ?? '-' }}</div>
                        </td>
                        <td class="font-semibold">Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
                        <td>
                            <span class="badge {{ $invoice->status->badgeClass() }}">{{ $invoice->status->label() }}</span>
                            <span class="badge badge-danger" style="margin-left: 4px; font-size: 10px;">Terhapus</span>
                        </td>
                        <td class="text-sm">
                            <span style="font-weight: 500;">{{ $invoice->deleted_at->format('d M Y, H:i') }}</span>
                            <span class="text-xs text-secondary" style="display: block;">{{ $invoice->deleted_at->diffForHumans() }}</span>
                        </td>
                        <td>
                            <div class="flex items-center gap-2">
                                @can('invoices.restore')
                                <form method="POST" action="{{ route('admin.invoices.restore', $invoice->id) }}" onsubmit="return confirm('Pulihkan invoice {{ $invoice->invoice_number }}?')">
                                    @csrf
                                    <button type="submit" class="btn btn-success btn-xs" style="display: flex; align-items: center; gap: 4px;">
                                        <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                                        Pulihkan
                                    </button>
                                </form>
                                @endcan
                                <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => request()->fullUrl()]) }}" class="btn btn-outline btn-xs">
                                    Detail
                                </a>
                            </div>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 48px; color: var(--text-secondary);">
                            <div style="font-size: 32px; margin-bottom: 8px;">🗑️</div>
                            <p style="font-weight: 500; font-size: 15px;">Tempat sampah invoice kosong.</p>
                            <span class="text-xs text-secondary">Tidak ada data invoice tagihan yang dihapus.</span>
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        <div class="pagination mt-4">{{ $trashedInvoices->links() }}</div>
    @endif
</div>
@endsection
