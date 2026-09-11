@extends('admin.layouts.app')

@section('title', 'Laporan Invoice & Pendapatan')
@section('header_title', 'Laporan Invoice')

@section('content')
<!-- Summary Cards -->
<div class="grid grid-4" style="margin-bottom: 24px;">
    <div class="card stat-card" style="margin-bottom: 0;">
        <div class="stat-value" style="color: var(--success);">Rp {{ number_format($totalRevenue, 0, ',', '.') }}</div>
        <div class="stat-label">Total Omset Lunas (PAID)</div>
    </div>
    <div class="card stat-card" style="margin-bottom: 0;">
        <div class="stat-value" style="color: var(--primary);">Rp {{ number_format($totalInvoiced, 0, ',', '.') }}</div>
        <div class="stat-label">Total Nilai Tagihan Diterbitkan</div>
    </div>
    <div class="card stat-card" style="margin-bottom: 0;">
        <div class="stat-value" style="color: var(--secondary);">{{ $countPaid }}</div>
        <div class="stat-label">Invoice Lunas</div>
    </div>
    <div class="card stat-card" style="margin-bottom: 0;">
        <div class="stat-value" style="color: var(--text-primary);">{{ $countTotal }}</div>
        <div class="stat-label">Total Faktur / Transaksi</div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <h2 class="card-title">Filter Rekapitulasi Invoice</h2>
            <p class="text-muted text-sm">Pilih rentang tanggal dan status untuk analisis keuangan.</p>
        </div>
        <div style="display: flex; gap: 8px;">
            <a href="{{ route('admin.invoices.report-pdf', request()->all()) }}" class="btn btn-secondary btn-sm" target="_blank">
                <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
                Unduh PDF Laporan
            </a>
        </div>
    </div>

    <form method="GET" action="{{ route('admin.invoices.report') }}" class="search-bar" style="display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap;">
        <div style="display: flex; flex-direction: column; gap: 4px;">
            <label class="form-label text-xs" style="margin: 0;">Dari Tanggal</label>
            <input type="date" name="from_date" class="form-control" value="{{ $fromDate }}">
        </div>
        <div style="display: flex; flex-direction: column; gap: 4px;">
            <label class="form-label text-xs" style="margin: 0;">Sampai Tanggal</label>
            <input type="date" name="to_date" class="form-control" value="{{ $toDate }}">
        </div>
        <div style="display: flex; flex-direction: column; gap: 4px;">
            <label class="form-label text-xs" style="margin: 0;">Status Invoice</label>
            <select name="status" class="form-control">
                <option value="all" {{ $status === 'all' || empty($status) ? 'selected' : '' }}>Semua Status</option>
                @foreach($statuses as $st)
                    <option value="{{ $st->value }}" {{ $status === $st->value ? 'selected' : '' }}>{{ $st->label() }}</option>
                @endforeach
            </select>
        </div>
        <div style="display: flex; flex-direction: column; gap: 4px;">
            <label class="form-label text-xs" style="margin: 0;">Tenant</label>
            <select name="tenant_id" class="form-control">
                <option value="">Semua Tenant</option>
                @foreach($tenants as $t)
                    <option value="{{ $t->id }}" {{ $tenantId == $t->id ? 'selected' : '' }}>{{ $t->name }}</option>
                @endforeach
            </select>
        </div>
        <button type="submit" class="btn btn-primary btn-sm" style="height: 42px;">Tampilkan</button>
        @if(request()->hasAny(['from_date', 'to_date', 'status', 'tenant_id']))
            <a href="{{ route('admin.invoices.report') }}" class="btn btn-outline btn-sm" style="height: 42px; line-height: 26px;">Reset</a>
        @endif
    </form>

    <div class="table-responsive" style="margin-top: 16px;">
        <table class="table">
            <thead>
                <tr>
                    <th>No. Invoice</th>
                    <th>Tenant / Pelanggan</th>
                    <th>Tanggal Terbit</th>
                    <th>Item & Paket</th>
                    <th>Nominal</th>
                    <th>Status</th>
                    <th style="text-align: right;">Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse($invoices as $inv)
                    <tr>
                        <td class="font-mono text-sm" style="font-weight: 600;">
                            <a href="{{ route('admin.invoices.show', $inv) }}" style="color: var(--primary); text-decoration: none;">
                                {{ $inv->invoice_number }}
                            </a>
                        </td>
                        <td>
                            <div style="font-weight: 500;">{{ $inv->tenant?->name ?? 'Non-Tenant' }}</div>
                            <div class="text-xs text-muted">{{ $inv->tenant?->email }}</div>
                        </td>
                        <td class="text-sm">{{ $inv->created_at ? $inv->created_at->format('d M Y') : '-' }}</td>
                        <td class="text-sm">
                            @foreach($inv->items as $item)
                                <span class="badge badge-info" style="font-size: 10px;">{{ $item->package?->name ?? 'Custom Item' }} ({{ $item->quantity }}x)</span>
                            @endforeach
                        </td>
                        <td style="font-weight: 700; color: var(--text-primary);">
                            Rp {{ number_format($inv->total_amount, 0, ',', '.') }}
                        </td>
                        <td>
                            <span class="badge {{ $inv->status->badgeClass() }}">{{ $inv->status->label() }}</span>
                        </td>
                        <td style="text-align: right;">
                            <a href="{{ route('admin.invoices.show', $inv) }}" class="btn btn-outline btn-xs">Detail</a>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="7" style="text-align: center; padding: 32px; color: var(--text-secondary);">
                            Tidak ada invoice pada periode dan kriteria filter yang dipilih.
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    @if($invoices->hasPages())
        <div class="pagination-container">
            <div class="pagination-info">
                Menampilkan <span>{{ $invoices->firstItem() ?? 0 }}</span> - <span>{{ $invoices->lastItem() ?? 0 }}</span> dari <span>{{ $invoices->total() }}</span> invoice
            </div>
            {{ $invoices->links() }}
        </div>
    @endif
</div>
@endsection
