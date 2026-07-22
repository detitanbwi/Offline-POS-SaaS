@extends('admin.layouts.app')
@section('title', 'Lisensi & Perangkat - POS SaaS Admin')
@section('header_title', 'Lisensi & Perangkat')

@section('content')
<div class="card">
    <div class="card-header"><h3 class="card-title">Daftar Token Lisensi & Perangkat Terikat</h3></div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari token, tenant, atau perangkat..." value="{{ request('search') }}">
        <select name="status" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Status Lisensi</option>
            @foreach ($statuses as $s)
                <option value="{{ $s->value }}" {{ request('status') === $s->value ? 'selected' : '' }}>{{ $s->label() }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
    </form>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Token Key</th>
                    <th>Tenant</th>
                    <th>Status Lisensi</th>
                    <th>Perangkat Terikat</th>
                    <th>Status Perangkat</th>
                    <th>Terakhir Validasi</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($tokens as $token)
                <tr>
                    <td><span class="token-display">{{ $token->token_key }}</span></td>
                    <td class="text-sm" style="font-weight: 500;">{{ $token->tenant?->name ?? '-' }}</td>
                    <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                    <td class="text-sm">
                        @if ($token->device)
                            <div style="font-weight: 600;">{{ $token->device->display_name }}</div>
                            <div class="text-xs text-muted">{{ filter_var(implode(' ', array_filter([$token->device->manufacturer, $token->device->brand, $token->device->model])), FILTER_DEFAULT) ?: 'Hardware ID: ' . substr($token->device->fingerprint_hash, 0, 8) }}</div>
                        @else
                            <span class="text-muted">- Belum Terikat -</span>
                        @endif
                    </td>
                    <td>
                        @if ($token->device)
                            <span class="badge {{ $token->device->status->badgeClass() }}">{{ $token->device->status->label() }}</span>
                        @else
                            <span class="text-muted">-</span>
                        @endif
                    </td>
                    <td class="text-sm text-muted">
                        {{ $token->last_validated_at ? $token->last_validated_at->format('d/m/Y H:i') : ($token->activated_at ? $token->activated_at->format('d/m/Y H:i') : '-') }}
                    </td>
                    <td>
                        <div class="flex gap-2">
                            <a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a>
                            @if ($token->device && $token->device->status->value === 'active')
                                <form method="POST" action="{{ route('admin.tokens.reset-device', $token) }}" onsubmit="return confirm('Reset perangkat dari token ini? Token akan kembali tersedia untuk digunakan.')" style="display:inline;">
                                    @csrf
                                    <button type="submit" class="btn btn-warning btn-xs">Reset Perangkat</button>
                                </form>
                            @endif
                        </div>
                    </td>
                </tr>
                @empty
                <tr><td colspan="7" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada data token lisensi & perangkat.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $tokens->withQueryString()->links() }}</div>
</div>
@endsection
