@extends('admin.layouts.app')
@section('title', 'Token Lisensi — POS SaaS Admin')
@section('header_title', 'Token Lisensi')

@section('content')
<div class="card">
    <div class="card-header"><h3 class="card-title">Daftar Token</h3></div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari token atau tenant..." value="{{ request('search') }}">
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
            <thead><tr><th>Token Key</th><th>Tenant</th><th>Status</th><th>Perangkat</th><th>Dibuat</th><th>Aksi</th></tr></thead>
            <tbody>
                @forelse ($tokens as $token)
                <tr>
                    <td><span class="token-display">{{ $token->token_key }}</span></td>
                    <td class="text-sm">{{ $token->tenant?->name }}</td>
                    <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                    <td class="text-sm">{{ $token->device?->display_name ?? '-' }}</td>
                    <td class="text-sm text-muted">{{ $token->created_at->format('d/m/Y') }}</td>
                    <td><a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada token.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $tokens->withQueryString()->links() }}</div>
</div>
@endsection
