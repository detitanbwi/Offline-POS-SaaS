@extends('admin.layouts.app')
@section('title', 'Token ' . $token->token_key . ' - Kasir Pro Admin')
@section('header_title', 'Detail Token')

@section('content')
<div class="grid grid-2">
    <div class="card">
        <div class="card-header"><h3 class="card-title">Informasi Token</h3></div>
        <div class="detail-grid">
            <div class="detail-label">Token Key</div><div class="detail-value"><span class="token-display">{{ $token->token_key }}</span></div>
            <div class="detail-label">Status</div><div class="detail-value"><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></div>
            <div class="detail-label">Tenant</div><div class="detail-value"><a href="{{ route('admin.tenants.show', $token->tenant) }}">{{ $token->tenant->name }}</a></div>
            <div class="detail-label">Paket</div><div class="detail-value">{{ $token->subscription?->package_name }}</div>
            <div class="detail-label">Diaktifkan</div><div class="detail-value">{{ $token->activated_at?->format('d F Y, H:i') ?? '-' }}</div>
            <div class="detail-label">Validasi Terakhir</div><div class="detail-value">{{ $token->last_validated_at?->format('d F Y, H:i') ?? '-' }}</div>
            <div class="detail-label">Subscription Berakhir</div><div class="detail-value">{{ $token->subscription?->expiry_date?->format('d F Y') ?? '-' }}</div>
        </div>
    </div>

    <div class="card">
        <div class="card-header"><h3 class="card-title">Perangkat Terikat</h3></div>
        @if ($token->device)
            <div class="detail-grid">
                <div class="detail-label">Status</div><div class="detail-value"><span class="badge {{ $token->device->status->badgeClass() }}">{{ $token->device->status->label() }}</span></div>
                <div class="detail-label">Brand</div><div class="detail-value">{{ $token->device->brand ?? '-' }}</div>
                <div class="detail-label">Model</div><div class="detail-value">{{ $token->device->model ?? '-' }}</div>
                <div class="detail-label">Manufacturer</div><div class="detail-value">{{ $token->device->manufacturer ?? '-' }}</div>
                <div class="detail-label">Fingerprint</div><div class="detail-value text-xs font-mono">{{ Str::limit($token->device->fingerprint_hash, 20) }}...</div>
                <div class="detail-label">Diaktifkan</div><div class="detail-value">{{ $token->device->activated_at?->format('d F Y, H:i') }}</div>
                <div class="detail-label">Validasi Terakhir</div><div class="detail-value">{{ $token->device->last_validated_at?->format('d F Y, H:i') ?? '-' }}</div>
            </div>
        @else
            <p class="text-muted" style="padding: 16px 0;">Belum ada perangkat terikat pada token ini.</p>
        @endif
    </div>
</div>

<div class="card">
    <div class="card-header"><h3 class="card-title">Aksi</h3></div>
    <div class="flex gap-3 flex-wrap">
        @if ($token->device && $token->status->value === 'active')
            <form method="POST" action="{{ route('admin.tokens.reset-device', $token) }}" onsubmit="return confirm('Reset perangkat dari token ini? Token akan kembali tersedia.')">
                @csrf
                <button class="btn btn-warning btn-sm">⟳ Reset Perangkat</button>
            </form>
        @endif
        @if (in_array($token->status->value, ['available', 'active']))
            <form method="POST" action="{{ route('admin.tokens.revoke', $token) }}" onsubmit="return confirm('Cabut token ini? Token tidak dapat digunakan kembali.')">
                @csrf
                <button class="btn btn-danger btn-sm">✕ Cabut Token</button>
            </form>
        @endif
        <a href="{{ route('admin.tokens.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
    </div>
</div>
@endsection
