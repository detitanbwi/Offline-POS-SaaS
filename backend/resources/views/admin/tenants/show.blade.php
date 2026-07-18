@extends('admin.layouts.app')
@section('title', "Tenant {{ $tenant->name }} — POS SaaS Admin")
@section('header_title', $tenant->name)

@section('content')
<div class="grid grid-2">
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Informasi Tenant</h3>
            <span class="badge {{ $tenant->status->badgeClass() }}">{{ $tenant->status->label() }}</span>
        </div>
        <div class="detail-grid">
            <div class="detail-label">Nama</div><div class="detail-value">{{ $tenant->name }}</div>
            <div class="detail-label">Pemilik</div><div class="detail-value">{{ $tenant->owner_name }}</div>
            <div class="detail-label">Email</div><div class="detail-value">{{ $tenant->email }}</div>
            <div class="detail-label">Telepon</div><div class="detail-value">{{ $tenant->phone ?? '-' }}</div>
            <div class="detail-label">Toko</div><div class="detail-value">{{ $tenant->store_name ?? '-' }}</div>
            <div class="detail-label">Alamat</div><div class="detail-value">{{ $tenant->store_address ?? '-' }}</div>
            <div class="detail-label">Bergabung</div><div class="detail-value">{{ $tenant->created_at->format('d F Y') }}</div>
        </div>
        <div class="flex gap-3 mt-4 flex-wrap">
            <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-sm">Edit</a>
            @if ($tenant->status->value === 'active')
                <form method="POST" action="{{ route('admin.tenants.suspend', $tenant) }}" onsubmit="return confirm('Tangguhkan tenant ini?')">@csrf<button class="btn btn-warning btn-sm">Tangguhkan</button></form>
            @elseif ($tenant->status->value === 'suspended')
                <form method="POST" action="{{ route('admin.tenants.reactivate', $tenant) }}" onsubmit="return confirm('Aktifkan kembali tenant ini?')">@csrf<button class="btn btn-success btn-sm">Aktifkan</button></form>
            @endif
            <form method="POST" action="{{ route('admin.tenants.destroy', $tenant) }}" onsubmit="return confirm('Hapus tenant ini? Data akan dihapus.')">@csrf @method('DELETE')<button class="btn btn-danger btn-sm">Hapus</button></form>
        </div>
    </div>

    <div class="card">
        <div class="card-header"><h3 class="card-title">Invoice Terbaru</h3></div>
        @if ($tenant->invoices->count() > 0)
            @foreach ($tenant->invoices as $inv)
            <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid var(--divider);">
                <div>
                    <span class="font-mono text-sm" style="font-weight:600;">{{ $inv->invoice_number }}</span>
                    <span class="badge {{ $inv->status->badgeClass() }}" style="margin-left:8px;">{{ $inv->status->label() }}</span>
                </div>
                <a href="{{ route('admin.invoices.show', $inv) }}" class="text-sm" style="color:var(--primary);">Detail →</a>
            </div>
            @endforeach
        @else
            <p class="text-muted text-sm">Belum ada invoice.</p>
        @endif
    </div>
</div>

@if ($tenant->licenseTokens->count() > 0)
<div class="card">
    <div class="card-header"><h3 class="card-title">Token Lisensi ({{ $tenant->licenseTokens->count() }})</h3></div>
    <div class="table-responsive">
        <table class="table">
            <thead><tr><th>Token</th><th>Status</th><th>Perangkat</th><th>Aksi</th></tr></thead>
            <tbody>
                @foreach ($tenant->licenseTokens as $token)
                <tr>
                    <td><span class="token-display">{{ $token->token_key }}</span></td>
                    <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                    <td>{{ $token->device?->display_name ?? '-' }}</td>
                    <td><a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
@endif

<a href="{{ route('admin.tenants.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
@endsection
