@extends('admin.layouts.app')
@section('title', 'Kelola Tenant - Kasir Pro Admin')
@section('header_title', 'Kelola Tenant')

@section('content')
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Daftar Tenant</h3>
        <a href="{{ route('admin.tenants.create') }}" class="btn btn-primary btn-sm">+ Tambah Tenant</a>
    </div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nama, email, atau toko..." value="{{ request('search') }}">
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
            <thead><tr><th>Nama</th><th>Pemilik</th><th>Email</th><th>Toko</th><th>Status</th><th>Aksi</th></tr></thead>
            <tbody>
                @forelse ($tenants as $tenant)
                <tr>
                    <td style="font-weight:600;">{{ $tenant->name }}</td>
                    <td>{{ $tenant->owner_name }}</td>
                    <td class="text-sm">{{ $tenant->email }}</td>
                    <td class="text-sm">{{ $tenant->store_name ?? '-' }}</td>
                    <td><span class="badge {{ $tenant->status->badgeClass() }}">{{ $tenant->status->label() }}</span></td>
                    <td>
                        <a href="{{ route('admin.tenants.show', $tenant) }}" class="btn btn-outline btn-xs">Detail</a>
                        <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-xs">Edit</a>
                    </td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada tenant.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $tenants->withQueryString()->links() }}</div>
</div>
@endsection
