@extends('admin.layouts.app')

@section('title', 'Manajemen Pengguna & Hak Akses')
@section('header_title', 'Manajemen Pengguna & RBAC')

@section('content')
<!-- Nav Tabs -->
<div style="display: flex; gap: 8px; border-bottom: 2px solid var(--divider); margin-bottom: 24px;">
    <a href="{{ route('admin.users.index') }}" style="padding: 12px 20px; font-weight: 700; font-size: 14px; text-decoration: none; color: var(--primary); border-bottom: 3px solid var(--primary); margin-bottom: -2px;">
        <span style="display: flex; align-items: center; gap: 8px;">
            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/></svg>
            Daftar Pengguna
        </span>
    </a>
    <a href="{{ route('admin.roles.index') }}" style="padding: 12px 20px; font-weight: 600; font-size: 14px; text-decoration: none; color: var(--text-secondary); border-bottom: 3px solid transparent; margin-bottom: -2px;">
        <span style="display: flex; align-items: center; gap: 8px;">
            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
            Role & Hak Akses Granular
        </span>
    </a>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <h2 class="card-title">Daftar Pengguna Administrator</h2>
            <p class="text-muted text-sm">Kelola akun admin dan pembagian role / wewenang sistem (Super Admin & Operator).</p>
        </div>
        @can('users.create')
        <a href="{{ route('admin.users.create') }}" class="btn btn-primary btn-sm">
            <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/></svg>
            Tambah Pengguna
        </a>
        @endcan
    </div>

    <form method="GET" action="{{ route('admin.users.index') }}" class="search-bar">
        <input type="text" name="search" class="form-control" placeholder="Cari nama atau email..." value="{{ request('search') }}">
        <select name="role_id" class="form-control">
            <option value="">Semua Role</option>
            @foreach($roles as $role)
                <option value="{{ $role->id }}" {{ request('role_id') == $role->id ? 'selected' : '' }}>{{ $role->name }}</option>
            @endforeach
        </select>
        <button type="submit" class="btn btn-primary btn-sm">Filter</button>
        @if(request()->hasAny(['search', 'role_id']))
            <a href="{{ route('admin.users.index') }}" class="btn btn-outline btn-sm">Reset</a>
        @endif
    </form>

    <div class="table-responsive">
        <table class="table">
            <thead>
                <tr>
                    <th>Pengguna</th>
                    <th>Email</th>
                    <th>Role / Hak Akses</th>
                    <th>Terdaftar Pada</th>
                    <th style="text-align: right;">Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse($users as $user)
                    <tr>
                        <td>
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <div class="user-avatar" style="width: 32px; height: 32px; font-size: 12px;">
                                    {{ strtoupper(substr($user->name, 0, 1)) }}
                                </div>
                                <div>
                                    <div style="font-weight: 600; color: var(--text-primary);">
                                        {{ $user->name }}
                                        @if(auth()->id() === $user->id)
                                            <span class="badge badge-info" style="font-size: 10px; margin-left: 4px;">Anda</span>
                                        @endif
                                    </div>
                                </div>
                            </div>
                        </td>
                        <td class="font-mono text-sm">{{ $user->email }}</td>
                        <td>
                            @if($user->role?->slug === 'super_admin' || $user->isSuperAdmin())
                                <span class="badge badge-success" style="font-weight: 700;">Super Admin</span>
                            @elseif($user->role?->slug === 'operator')
                                <span class="badge badge-warning" style="font-weight: 600;">Operator</span>
                            @else
                                <span class="badge badge-info">{{ $user->role?->name ?? 'Admin' }}</span>
                            @endif
                        </td>
                        <td class="text-sm text-muted">{{ $user->created_at ? $user->created_at->format('d M Y, H:i') : '-' }}</td>
                        <td style="text-align: right;">
                            <div style="display: flex; gap: 8px; justify-content: flex-end;">
                                @can('users.edit')
                                <a href="{{ route('admin.users.edit', $user) }}" class="btn btn-outline btn-xs">Edit</a>
                                @endcan

                                @can('users.delete')
                                @if(auth()->id() !== $user->id)
                                    <form action="{{ route('admin.users.destroy', $user) }}" method="POST" onsubmit="return confirm('Apakah Anda yakin ingin menghapus pengguna {{ $user->name }}?');" style="display: inline;">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-danger btn-xs">Hapus</button>
                                    </form>
                                @endif
                                @endcan
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="5" style="text-align: center; padding: 32px; color: var(--text-secondary);">
                            Tidak ada data pengguna yang sesuai.
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    @if($users->hasPages())
        <div class="pagination-container">
            <div class="pagination-info">
                Menampilkan <span>{{ $users->firstItem() ?? 0 }}</span> - <span>{{ $users->lastItem() ?? 0 }}</span> dari <span>{{ $users->total() }}</span> pengguna
            </div>
            {{ $users->links() }}
        </div>
    @endif
</div>
@endsection
