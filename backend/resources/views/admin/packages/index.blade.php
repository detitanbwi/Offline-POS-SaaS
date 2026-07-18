@extends('admin.layouts.app')
@section('title', 'Paket — POS SaaS Admin')
@section('header_title', 'Kelola Paket')

@section('content')
<div class="card">
    <div class="card-header">
        <h3 class="card-title">Daftar Paket</h3>
        <a href="{{ route('admin.packages.create') }}" class="btn btn-primary btn-sm">+ Tambah Paket</a>
    </div>
    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr><th>Nama</th><th>Harga</th><th>Durasi Default</th><th>Status</th><th>Urutan</th><th>Aksi</th></tr>
            </thead>
            <tbody>
                @forelse ($packages as $pkg)
                <tr>
                    <td style="font-weight: 600;">{{ $pkg->name }}<br><span class="text-xs text-muted font-mono">{{ $pkg->slug }}</span></td>
                    <td>Rp {{ number_format($pkg->price, 0, ',', '.') }}</td>
                    <td>{{ $pkg->default_duration_days }} hari</td>
                    <td><span class="badge {{ $pkg->is_active ? 'badge-success' : 'badge-danger' }}">{{ $pkg->is_active ? 'Aktif' : 'Nonaktif' }}</span></td>
                    <td>{{ $pkg->sort_order }}</td>
                    <td>
                        <a href="{{ route('admin.packages.edit', $pkg) }}" class="btn btn-outline btn-xs">Edit</a>
                        <form method="POST" action="{{ route('admin.packages.destroy', $pkg) }}" style="display:inline;" onsubmit="return confirm('Hapus paket ini?')">@csrf @method('DELETE')<button class="btn btn-danger btn-xs">Hapus</button></form>
                    </td>
                </tr>
                @empty
                <tr><td colspan="6" style="text-align:center;padding:32px;color:var(--text-secondary);">Belum ada paket.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="pagination">{{ $packages->links() }}</div>
</div>
@endsection
