@extends('admin.layouts.app')
@section('title', 'Kelola Tenant - Kasir Pro Admin')
@section('header_title', 'Kelola Tenant')

@section('content')
<div class="card">
    <div class="card-header flex justify-between items-center flex-wrap gap-2">
        <h3 class="card-title">Daftar Tenant (Toko)</h3>
        <div class="flex gap-2 items-center">
            <a href="{{ route('admin.trash.index', ['tab' => 'tenants']) }}" class="btn btn-outline btn-sm">
                🗑️ Tempat Sampah
            </a>
            @can('tenants.create')
                <a href="{{ route('admin.tenants.create') }}" class="btn btn-primary btn-sm">+ Tambah Tenant</a>
            @endcan
        </div>
    </div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nama, email, atau toko..." value="{{ request('search') }}">
        <select name="status" class="form-control" onchange="this.form.submit()">
            <option value="">Semua Status Aktif</option>
            @foreach ($statuses as $s)
                <option value="{{ $s->value }}" {{ request('status') === $s->value ? 'selected' : '' }}>{{ $s->label() }}</option>
            @endforeach
            <option value="trashed" {{ request('status') === 'trashed' ? 'selected' : '' }}>🗑️ Terhapus (Tempat Sampah)</option>
        </select>
        <button type="submit" class="btn btn-outline btn-sm">Cari</button>
        @if (request('status') || request('search'))
            <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline btn-sm">Reset</a>
        @endif
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
                    <td>
                        @if ($tenant->trashed())
                            <span class="badge badge-danger">Terhapus</span>
                            <span class="text-xs text-secondary" style="display: block;">{{ $tenant->deleted_at->format('d/m/y H:i') }}</span>
                        @else
                            <span class="badge {{ $tenant->status->badgeClass() }}">{{ $tenant->status->label() }}</span>
                        @endif
                    </td>
                    <td>
                        @if ($tenant->trashed())
                            @can('tenants.restore')
                                <form method="POST" action="{{ route('admin.tenants.restore', $tenant->id) }}" style="display: inline;" onsubmit="return confirm('Pulihkan data tenant {{ $tenant->name }}?')">
                                    @csrf
                                    <button type="submit" class="btn btn-success btn-xs">Pulihkan</button>
                                </form>
                            @endcan
                        @else
                            <a href="{{ route('admin.tenants.show', $tenant) }}" class="btn btn-outline btn-xs">Detail</a>
                            @can('tenants.edit')
                                <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-xs">Edit</a>
                            @endcan
                            @can('tenants.delete')
                                <form method="POST" action="{{ route('admin.tenants.destroy', $tenant) }}" style="display: inline;" onsubmit="return confirm('Pindahkan tenant {{ $tenant->name }} ke tempat sampah (Soft Delete)?')">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-danger btn-xs">Hapus</button>
                                </form>
                            @endcan
                        @endif
                    </td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada tenant yang sesuai kriteria.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $tenants->withQueryString()->links() }}</div>
</div>
@endsection
