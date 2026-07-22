@extends('admin.layouts.app')
@section('title', 'Perangkat ' . $device->display_name . ' - POS SaaS Admin')
@section('header_title', 'Detail Perangkat')

@section('content')
<div class="grid grid-2">
    <div class="card">
        <div class="card-header"><h3 class="card-title">Informasi Perangkat</h3></div>
        <div class="detail-grid">
            <div class="detail-label">Status</div><div class="detail-value"><span class="badge {{ $device->status->badgeClass() }}">{{ $device->status->label() }}</span></div>
            <div class="detail-label">Brand</div><div class="detail-value">{{ $device->brand ?? '-' }}</div>
            <div class="detail-label">Model</div><div class="detail-value">{{ $device->model ?? '-' }}</div>
            <div class="detail-label">Manufacturer</div><div class="detail-value">{{ $device->manufacturer ?? '-' }}</div>
            <div class="detail-label">Fingerprint Hash</div><div class="detail-value text-xs font-mono" style="word-break:break-all;">{{ $device->fingerprint_hash }}</div>
            <div class="detail-label">Diaktifkan</div><div class="detail-value">{{ $device->activated_at?->format('d F Y, H:i') }}</div>
            <div class="detail-label">Validasi Terakhir</div><div class="detail-value">{{ $device->last_validated_at?->format('d F Y, H:i') ?? '-' }}</div>
        </div>
    </div>
    <div class="card">
        <div class="card-header"><h3 class="card-title">Token & Tenant</h3></div>
        <div class="detail-grid">
            <div class="detail-label">Tenant</div><div class="detail-value"><a href="{{ route('admin.tenants.show', $device->tenant) }}">{{ $device->tenant->name }}</a></div>
            <div class="detail-label">Token</div><div class="detail-value"><a href="{{ route('admin.tokens.show', $device->licenseToken) }}" class="font-mono">{{ $device->licenseToken?->token_key }}</a></div>
            <div class="detail-label">Subscription</div><div class="detail-value">{{ $device->licenseToken?->subscription?->package_name ?? '-' }}</div>
            <div class="detail-label">Sub. Berakhir</div><div class="detail-value">{{ $device->licenseToken?->subscription?->expiry_date?->format('d F Y') ?? '-' }}</div>
        </div>
    </div>
</div>
<a href="{{ route('admin.devices.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
@endsection
