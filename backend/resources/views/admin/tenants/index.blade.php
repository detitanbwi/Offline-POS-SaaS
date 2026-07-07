@extends('admin.layouts.app')

@section('title', 'Kelola Tenant — POS SaaS')
@section('header_title', 'Daftar Tenant POS')

@section('content')
    <div class="card">
        <div class="card-header" style="flex-wrap: wrap; gap: 16px;">
            <form action="{{ route('admin.tenants.index') }}" method="GET" style="display: flex; gap: 12px; flex-grow: 1; max-width: 600px;">
                <input type="text" name="search" class="form-control" placeholder="Cari nama tenant, email, atau owner..." value="{{ request('search') }}">
                <select name="status" class="form-control" style="width: 150px;">
                    <option value="">Semua Status</option>
                    <option value="active" {{ request('status') === 'active' ? 'selected' : '' }}>Aktif</option>
                    <option value="suspended" {{ request('status') === 'suspended' ? 'selected' : '' }}>Ditangguhkan</option>
                </select>
                <button type="submit" class="btn btn-primary">Filter</button>
            </form>
            <a href="{{ route('admin.tenants.create') }}" class="btn btn-secondary">+ Tambah Tenant</a>
        </div>

        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Nama Bisnis</th>
                        <th>Owner</th>
                        <th>Email / Telepon</th>
                        <th>Nama Toko</th>
                        <th>Status</th>
                        <th style="text-align: right;">Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($tenants as $tenant)
                        <tr>
                            <td>
                                <strong style="color: var(--primary);">{{ $tenant->name }}</strong>
                            </td>
                            <td>{{ $tenant->owner_name }}</td>
                            <td>
                                <div>{{ $tenant->email }}</div>
                                <div style="font-size: 12px; color: var(--text-secondary);">{{ $tenant->phone ?? '-' }}</div>
                            </td>
                            <td>{{ $tenant->store_name ?? '-' }}</td>
                            <td>
                                @if($tenant->status === 'active')
                                    <span class="badge badge-success">Aktif</span>
                                @elseif($tenant->status === 'suspended')
                                    <span class="badge badge-warning">Ditangguhkan</span>
                                @else
                                    <span class="badge badge-danger">{{ $tenant->status }}</span>
                                @endif
                            </td>
                            <td style="text-align: right;">
                                <div style="display: inline-flex; gap: 8px;">
                                    <a href="{{ route('admin.tenants.show', $tenant->id) }}" class="btn btn-outline btn-sm">Detail</a>
                                    <a href="{{ route('admin.tenants.edit', $tenant->id) }}" class="btn btn-primary btn-sm">Edit</a>
                                    @if($tenant->status === 'active')
                                        <form action="{{ route('admin.tenants.suspend', $tenant->id) }}" method="POST" onsubmit="return confirm('Tangguhkan tenant ini?')">
                                            @csrf
                                            <button type="submit" class="btn btn-danger btn-sm" style="background-color: var(--warning); color: black;">Suspend</button>
                                        </form>
                                    @else
                                        <form action="{{ route('admin.tenants.reactivate', $tenant->id) }}" method="POST">
                                            @csrf
                                            <button type="submit" class="btn btn-primary btn-sm" style="background-color: var(--success);">Aktifkan</button>
                                        </form>
                                    @endif
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" style="text-align: center; color: var(--text-secondary); padding: 32px;">Belum ada tenant terdaftar.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div style="margin-top: 24px;">
            {{ $tenants->appends(request()->query())->links() }}
        </div>
    </div>
@endsection
