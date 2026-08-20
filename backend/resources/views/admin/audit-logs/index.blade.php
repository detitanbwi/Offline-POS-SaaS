@extends('admin.layouts.app')
@section('title', 'Audit Log - Kasir Pro Admin')
@section('header_title', 'Audit Log Keamanan')

@section('content')
<div class="card">
    <div class="card-header"><h3 class="card-title">Log Aktivitas</h3></div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari aksi, detail, atau IP..." value="{{ request('search') }}">
        <select name="action" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Aksi</option>
            @foreach ($actions as $action)
                <option value="{{ $action }}" {{ request('action') === $action ? 'selected' : '' }}>{{ $action }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
    </form>
    <div class="table-responsive">
        <table class="table">
            <thead><tr><th>Waktu</th><th>Aksi</th><th>Tenant</th><th>Detail</th><th>IP</th><th>User</th></tr></thead>
            <tbody>
                @forelse ($logs as $log)
                <tr>
                    <td class="text-sm text-muted" style="white-space:nowrap;">{{ $log->created_at->format('d/m/Y H:i') }}</td>
                    <td><span class="badge badge-info">{{ $log->action }}</span></td>
                    <td class="text-sm">{{ $log->tenant?->name ?? '-' }}</td>
                    <td class="text-sm">{{ Str::limit($log->details, 80) }}</td>
                    <td class="text-xs text-muted font-mono">{{ $log->ip_address }}</td>
                    <td class="text-sm">{{ $log->user?->name ?? '-' }}</td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada log.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $logs->withQueryString()->links() }}</div>
</div>
@endsection
