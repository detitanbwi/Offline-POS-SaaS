@extends('admin.layouts.app')
@section('title', 'Subscription ' . $subscription->package_name . ' - POS SaaS Admin')
@section('header_title', 'Detail Subscription')

@section('content')
<div class="grid grid-2">
    <div class="card">
        <div class="card-header"><h3 class="card-title">Informasi Subscription</h3></div>
        <div class="detail-grid">
            <div class="detail-label">Paket</div><div class="detail-value" style="font-weight:600;">{{ $subscription->package_name }}</div>
            <div class="detail-label">Status</div><div class="detail-value"><span class="badge {{ $subscription->status->badgeClass() }}">{{ $subscription->status->label() }}</span></div>
            <div class="detail-label">Mulai</div><div class="detail-value">{{ $subscription->start_date->format('d F Y') }}</div>
            <div class="detail-label">Berakhir</div><div class="detail-value">{{ $subscription->expiry_date->format('d F Y') }}</div>
            <div class="detail-label">Sisa</div><div class="detail-value">{{ $subscription->remainingDays() }} hari</div>
            <div class="detail-label">Tenant</div><div class="detail-value"><a href="{{ route('admin.tenants.show', $subscription->tenant) }}">{{ $subscription->tenant->name }}</a></div>
        </div>
    </div>
    <div class="card">
        <div class="card-header"><h3 class="card-title">Invoice Terkait</h3></div>
        @if ($subscription->invoiceItem?->invoice)
            <div class="detail-grid">
                <div class="detail-label">No. Invoice</div>
                <div class="detail-value font-mono"><a href="{{ route('admin.invoices.show', $subscription->invoiceItem->invoice) }}">{{ $subscription->invoiceItem->invoice->invoice_number }}</a></div>
                <div class="detail-label">Qty</div><div class="detail-value">{{ $subscription->invoiceItem->quantity }}</div>
                <div class="detail-label">Durasi</div><div class="detail-value">{{ $subscription->invoiceItem->duration_days }} hari</div>
            </div>
        @else
            <p class="text-muted">Tidak ada data invoice.</p>
        @endif
    </div>
</div>

<div class="card">
    <div class="card-header"><h3 class="card-title">Token Lisensi ({{ $subscription->licenseTokens->count() }})</h3></div>
    <div class="table-responsive">
        <table class="table">
            <thead><tr><th>Token</th><th>Status</th><th>Perangkat</th><th>Diaktifkan</th><th>Aksi</th></tr></thead>
            <tbody>
                @forelse ($subscription->licenseTokens as $token)
                <tr>
                    <td><span class="token-display">{{ $token->token_key }}</span></td>
                    <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                    <td>{{ $token->device?->display_name ?? 'Belum terikat' }}</td>
                    <td class="text-sm">{{ $token->activated_at?->format('d/m/Y H:i') ?? '-' }}</td>
                    <td><a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @empty
                <tr><td colspan="5" style="text-align:center;padding:24px;color:var(--text-secondary);">Belum ada token.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
<a href="{{ route('admin.subscriptions.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
@endsection
