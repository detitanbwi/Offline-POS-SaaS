@extends('admin.layouts.app')
@section('title', 'Data Pelanggan & Lisensi - Kasir Pro Admin')
@section('header_title', 'Data Pelanggan')

@section('content')
<div class="card">
    <div class="card-header flex justify-between items-center flex-wrap gap-2">
        <div>
            <h3 class="card-title">Daftar Pelanggan & Lisensi</h3>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 2px;">
                Kelola data pelanggan (pribadi & perusahaan) serta lisensi perangkat yang dimiliki.
            </p>
        </div>
        <div class="flex gap-2 items-center">
            <a href="{{ route('admin.trash.index', ['tab' => 'tenants']) }}" class="btn btn-outline btn-sm">
                🗑️ Tempat Sampah
            </a>
            @can('tenants.create')
                <a href="{{ route('admin.tenants.create') }}" class="btn btn-primary btn-sm" id="btn_new_license_order">
                    <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                    </svg>
                    <span>+ Pesan Lisensi / Pelanggan Baru</span>
                </a>
            @endcan
        </div>
    </div>
    <form method="GET" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nama, email, pemilik, atau toko..." value="{{ request('search') }}">
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
            <thead>
                <tr>
                    <th>Nama Pelanggan / Bisnis</th>
                    <th>Tipe</th>
                    <th>Pemilik / PIC</th>
                    <th>Kontak</th>
                    <th>Toko / Outlet</th>
                    <th>Total Lisensi</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse ($tenants as $tenant)
                <tr>
                    <td style="font-weight:600;">
                        <a href="{{ route('admin.tenants.show', $tenant) }}" style="color: var(--primary); text-decoration: none;">
                            {{ $tenant->name }}
                        </a>
                        @if($tenant->tax_number)
                            <div style="font-size: 11px; color: var(--text-secondary); font-family: monospace;">NPWP: {{ $tenant->tax_number }}</div>
                        @endif
                    </td>
                    <td>
                        <span class="badge {{ $tenant->customer_type === 'company' ? 'badge-info' : 'badge-warning' }}">
                            {{ $tenant->customer_type_label }}
                        </span>
                    </td>
                    <td>{{ $tenant->owner_name }}</td>
                    <td class="text-sm">
                        <div>{{ $tenant->email }}</div>
                        @if($tenant->phone)
                            <div class="text-xs text-muted">{{ $tenant->phone }}</div>
                        @endif
                    </td>
                    <td class="text-sm">{{ $tenant->store_name ?? '-' }}</td>
                    <td>
                        <span class="badge badge-success" style="font-size: 12px; font-weight: 700;">
                            {{ $tenant->licenseTokens()->count() }} Perangkat
                        </span>
                    </td>
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
                            <div style="display: flex; gap: 4px;">
                                <a href="{{ route('admin.tenants.show', $tenant) }}" class="btn btn-outline btn-xs">Detail</a>
                                @can('tenants.edit')
                                    <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-xs">Edit</a>
                                @endcan
                                @can('tenants.delete')
                                    <form method="POST" action="{{ route('admin.tenants.destroy', $tenant) }}" style="display: inline;" onsubmit="return confirm('Pindahkan {{ $tenant->name }} ke tempat sampah (Soft Delete)?')">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-danger btn-xs">Hapus</button>
                                    </form>
                                @endcan
                            </div>
                        @endif
                    </td>
                </tr>
                @empty
                <tr><td colspan="8" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada data pelanggan yang sesuai kriteria.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $tenants->withQueryString()->links() }}</div>
</div>
@endsection
