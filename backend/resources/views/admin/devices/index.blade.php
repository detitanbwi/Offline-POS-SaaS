@extends('admin.layouts.app')
@section('title', 'Perangkat - POS SaaS Admin')
@section('header_title', 'Kelola Perangkat')

@section('content')
<div class="card">
    <div class="card-header"><h3 class="card-title">Daftar Perangkat</h3></div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari brand, model, atau tenant..." value="{{ request('search') }}">
        <select name="status" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Status</option>
            @foreach ($statuses as $s)
                <option value="{{ $s->value }}" {{ request('status') === $s->value ? 'selected' : '' }}>{{ $s->label() }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
    </form>
    <div class="table-responsive">
        <table class="table">
            <thead><tr><th>Perangkat</th><th>Tenant</th><th>Token</th><th>Status</th><th>Diaktifkan</th><th>Aksi</th></tr></thead>
            <tbody>
                @forelse ($devices as $device)
                <tr>
                    <td style="font-weight:500;">{{ $device->display_name }}<br><span class="text-xs text-muted">{{ $device->manufacturer }}</span></td>
                    <td class="text-sm">{{ $device->tenant?->name }}</td>
                    <td class="text-xs font-mono">{{ $device->licenseToken?->token_key ?? '-' }}</td>
                    <td><span class="badge {{ $device->status->badgeClass() }}">{{ $device->status->label() }}</span></td>
                    <td class="text-sm text-muted">{{ $device->activated_at?->format('d/m/Y') }}</td>
                    <td><a href="{{ route('admin.devices.show', $device) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada perangkat.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $devices->withQueryString()->links() }}</div>
</div>
@endsection
