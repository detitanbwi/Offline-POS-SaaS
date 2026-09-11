@extends('admin.layouts.app')
@section('title', 'Invoice - Kasir Pro Admin')
@section('header_title', 'Kelola Invoice')

@section('content')
<div class="card">
    <div class="card-header flex justify-between items-center flex-wrap gap-2">
        <h3 class="card-title" style="margin-bottom: 0;">Daftar Invoice</h3>
        <div class="flex gap-2 items-center">
            <a href="{{ route('admin.trash.index', ['tab' => 'invoices']) }}" class="btn btn-outline btn-sm">
                🗑️ Tempat Sampah
            </a>
            @can('invoices.create')
                <a href="{{ route('admin.invoices.create') }}" class="btn btn-primary btn-sm">+ Buat Invoice Baru</a>
            @endcan
        </div>
    </div>

    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nomor invoice atau tenant..." value="{{ request('search') }}">
        <select name="status" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Status</option>
            @foreach ($statuses as $status)
                <option value="{{ $status->value }}" {{ request('status') === $status->value ? 'selected' : '' }}>{{ $status->label() }}</option>
            @endforeach
            <option value="trashed" {{ request('status') === 'trashed' ? 'selected' : '' }}>🗑️ Terhapus (Tempat Sampah)</option>
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
        @if (request('status') || request('search'))
            <a href="{{ route('admin.invoices.index') }}" class="btn btn-outline btn-sm">Reset</a>
        @endif
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
                    <td class="font-mono" style="font-weight: 600;">
                        <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => request()->fullUrl()]) }}" style="color: var(--primary); text-decoration: none;">
                            {{ $invoice->invoice_number }}
                        </a>
                    </td>
                    <td>{{ $invoice->tenant?->name ?? '-' }}</td>
                    <td style="font-weight: 600;">Rp {{ number_format($invoice->total_amount, 0, ',', '.') }}</td>
                    <td>
                        @if ($invoice->trashed())
                            <span class="badge badge-danger">Terhapus</span>
                        @else
                            <span class="badge {{ $invoice->status->badgeClass() }}">{{ $invoice->status->label() }}</span>
                        @endif
                    </td>
                    <td class="text-sm text-muted">{{ $invoice->created_at->format('d/m/Y') }}</td>
                    <td>
                        <div class="flex items-center gap-1 flex-wrap">
                            <a href="{{ route('admin.invoices.show', ['invoice' => $invoice, 'return_to' => request()->fullUrl()]) }}" class="btn btn-outline btn-xs">Detail</a>
                            @if (!$invoice->trashed())
                                <a href="{{ route('admin.invoices.download-pdf', $invoice) }}" class="btn btn-sm btn-xs" style="background: var(--text-secondary); color: white;">PDF</a>
                                @can('invoices.delete')
                                    <form method="POST" action="{{ route('admin.invoices.destroy', $invoice) }}" style="display: inline;" onsubmit="return confirm('Pindahkan invoice {{ $invoice->invoice_number }} ke tempat sampah (Soft Delete)?')">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-danger btn-xs">Hapus</button>
                                    </form>
                                @endcan
                            @else
                                @can('invoices.restore')
                                    <form method="POST" action="{{ route('admin.invoices.restore', $invoice->id) }}" style="display: inline;" onsubmit="return confirm('Pulihkan invoice {{ $invoice->invoice_number }}?')">
                                        @csrf
                                        <button type="submit" class="btn btn-success btn-xs">Pulihkan</button>
                                    </form>
                                @endcan
                            @endif
                        </div>
                    </td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align: center; padding: 32px; color: var(--text-secondary);">Belum ada invoice yang sesuai kriteria.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="pagination">{{ $invoices->withQueryString()->links() }}</div>
</div>
@endsection
