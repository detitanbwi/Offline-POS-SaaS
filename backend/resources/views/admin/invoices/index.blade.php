@extends('admin.layouts.app')
@section('title', 'Invoice - Kasir Pro Admin')
@section('header_title', 'Kelola Invoice')

@section('content')
<div class="card">
    <div class="card-header" style="display: flex; justify-content: space-between; align-items: center;">
        <h3 class="card-title" style="margin-bottom: 0;">Daftar Invoice</h3>
        @can('invoices.create')
            <a href="{{ route('admin.invoices.create') }}" class="btn btn-primary btn-sm">+ Buat Invoice Baru</a>
        @endcan
    </div>

    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nomor invoice atau tenant..." value="{{ request('search') }}">
        <select name="status" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Status</option>
            @foreach ($statuses as $status)
                <option value="{{ $status->value }}" {{ request('status') === $status->value ? 'selected' : '' }}>{{ $status->label() }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
    </form>

    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>No. Invoice</th>
                    <th>Tenant</th>
                    <th>Total</th>
                    <th>Status</th>
                    <th>Tanggal</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($invoices as $invoice)
                <tr>
                    <td class="font-mono" style="font-weight: 600;">{{ $invoice->invoice_number }}</td>
                    <td>{{ $invoice->tenant?->name ?? '-' }}</td>
                    <td style="font-weight: 600;">Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
                    <td><span class="badge {{ $invoice->status->badgeClass() }}">{{ $invoice->status->label() }}</span></td>
                    <td class="text-sm text-muted">{{ $invoice->created_at->format('d/m/Y') }}</td>
                    <td>
                        <a href="{{ route('admin.invoices.show', $invoice) }}" class="btn btn-outline btn-xs">Detail</a>
                        <a href="{{ route('admin.invoices.download-pdf', $invoice) }}" class="btn btn-sm btn-xs" style="background: var(--text-secondary); color: white;">PDF</a>
                    </td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align: center; padding: 32px; color: var(--text-secondary);">Belum ada invoice.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="pagination">{{ $invoices->withQueryString()->links() }}</div>
</div>
@endsection
