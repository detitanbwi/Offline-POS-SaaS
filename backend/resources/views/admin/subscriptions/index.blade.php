@extends('admin.layouts.app')
@section('title', 'Subscription - POS SaaS Admin')
@section('header_title', 'Kelola Subscription')

@section('content')
<div class="card">
    <div class="card-header"><h3 class="card-title">Daftar Subscription</h3></div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari tenant atau paket..." value="{{ request('search') }}">
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
            <thead><tr><th>Tenant</th><th>Paket</th><th>Mulai</th><th>Berakhir</th><th>Sisa</th><th>Status</th><th>Aksi</th></tr></thead>
            <tbody>
                @forelse ($subscriptions as $sub)
                <tr>
                    <td>{{ $sub->tenant?->name }}</td>
                    <td style="font-weight:600;">{{ $sub->package_name }}</td>
                    <td class="text-sm">{{ $sub->start_date->format('d/m/Y') }}</td>
                    <td class="text-sm">{{ $sub->expiry_date->format('d/m/Y') }}</td>
                    <td class="text-sm">{{ $sub->remainingDays() }} hari</td>
                    <td><span class="badge {{ $sub->status->badgeClass() }}">{{ $sub->status->label() }}</span></td>
                    <td><a href="{{ route('admin.subscriptions.show', $sub) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @empty
                <tr><td colspan="7" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada subscription.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $subscriptions->withQueryString()->links() }}</div>
</div>
@endsection
