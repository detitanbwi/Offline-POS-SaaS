@extends('admin.layouts.app')
@section('title', 'Dashboard - Kasir Pro Admin')
@section('header_title', 'Dashboard')

@section('content')
<div class="grid grid-5" style="margin-bottom: 32px;">
    <div class="card stat-card">
        <div class="stat-value">{{ $stats['active_tenants'] }}</div>
        <div class="stat-label">Tenant Aktif</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value" style="color: var(--warning);">{{ $stats['unpaid_invoices'] }}</div>
        <div class="stat-label">Invoice Belum Dibayar</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value" style="color: var(--success);">{{ $stats['active_subscriptions'] }}</div>
        <div class="stat-label">Subscription Aktif</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value">{{ $stats['active_tokens'] }}</div>
        <div class="stat-label">Token Aktif</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value">{{ $stats['total_devices'] }}</div>
        <div class="stat-label">Perangkat Aktif</div>
    </div>
</div>

<div class="grid grid-3" style="margin-bottom: 32px;">
    <div class="card stat-card">
        <div class="stat-value text-sm" style="font-size: 22px;">{{ $stats['total_tenants'] }}</div>
        <div class="stat-label">Total Tenant</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value text-sm" style="font-size: 22px; color: var(--success);">{{ $stats['paid_invoices'] }}</div>
        <div class="stat-label">Invoice Lunas</div>
    </div>
    <div class="card stat-card">
        <div class="stat-value text-sm" style="font-size: 22px; color: var(--secondary);">{{ $stats['available_tokens'] }}</div>
        <div class="stat-label">Token Tersedia</div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h3 class="card-title">Aktivitas Terbaru</h3>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Waktu</th>
                    <th>Aksi</th>
                    <th>Tenant</th>
                    <th>Detail</th>
                    <th>IP</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($stats['recent_activities'] as $log)
                <tr>
                    <td class="text-sm text-muted">{{ $log->created_at->format('d/m/Y H:i') }}</td>
                    <td><span class="badge badge-info">{{ $log->action }}</span></td>
                    <td class="text-sm">{{ $log->tenant?->name ?? '-' }}</td>
                    <td class="text-sm">{{ Str::limit($log->details, 60) }}</td>
                    <td class="text-sm text-muted font-mono">{{ $log->ip_address }}</td>
                </tr>
                @empty
                <tr><td colspan="5" style="text-align: center; padding: 32px; color: var(--text-secondary);">Belum ada aktivitas.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
@endsection
