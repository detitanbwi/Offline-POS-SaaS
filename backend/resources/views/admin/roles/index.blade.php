@extends('admin.layouts.app')

@section('title', 'Role & Hak Akses Granular (RBAC)')
@section('header_title', 'Manajemen Pengguna & RBAC')

@section('content')
<!-- Nav Tabs -->
<div style="display: flex; gap: 8px; border-bottom: 2px solid var(--divider); margin-bottom: 24px;">
    <a href="{{ route('admin.users.index') }}" style="padding: 12px 20px; font-weight: 600; font-size: 14px; text-decoration: none; color: var(--text-secondary); border-bottom: 3px solid transparent; margin-bottom: -2px;">
        <span style="display: flex; align-items: center; gap: 8px;">
            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/></svg>
            Daftar Pengguna
        </span>
    </a>
    <a href="{{ route('admin.roles.index') }}" style="padding: 12px 20px; font-weight: 700; font-size: 14px; text-decoration: none; color: var(--primary); border-bottom: 3px solid var(--primary); margin-bottom: -2px;">
        <span style="display: flex; align-items: center; gap: 8px;">
            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
            Role & Hak Akses Granular
        </span>
    </a>
</div>

<div class="card">
    <div class="card-header">
        <div>
            <h2 class="card-title">Daftar Role & Matriks Otorisasi</h2>
            <p class="text-muted text-sm">Atur wewenang dan batasan fitur setiap tingkatan akun admin secara granular per modul.</p>
        </div>
        <a href="{{ route('admin.roles.create') }}" class="btn btn-primary btn-sm">
            <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/></svg>
            Tambah Role Baru
        </a>
    </div>

    <div class="grid grid-2" style="margin-bottom: 24px;">
        @foreach($roles as $role)
            <div style="background-color: var(--surface); border: 1.5px solid var(--divider); border-radius: 16px; padding: 20px; display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                        <div style="display: flex; align-items: center; gap: 10px;">
                            <h3 style="font-size: 16px; font-weight: 700; color: var(--text-primary); margin: 0;">{{ $role->name }}</h3>
                            @if($role->slug === 'super_admin')
                                <span class="badge badge-success" style="font-size: 10px;">Full Control (100%)</span>
                            @elseif($role->slug === 'operator')
                                <span class="badge badge-warning" style="font-size: 10px;">Restricted</span>
                            @else
                                <span class="badge badge-info" style="font-size: 10px;">Custom Role</span>
                            @endif
                        </div>
                        <span class="text-muted text-xs font-mono">{{ $role->slug }}</span>
                    </div>

                    <p style="font-size: 13px; color: var(--text-secondary); margin-bottom: 16px; line-height: 1.5;">
                        {{ $role->description }}
                    </p>

                    <div style="display: flex; gap: 16px; margin-bottom: 16px; padding-top: 12px; border-top: 1px dashed var(--divider);">
                        <div>
                            <span class="text-xs text-muted">Pengguna Aktif:</span>
                            <div style="font-weight: 700; font-size: 14px; color: var(--text-primary);">{{ $role->users_count }} Akun</div>
                        </div>
                        <div>
                            <span class="text-xs text-muted">Hak Akses Granular:</span>
                            <div style="font-weight: 700; font-size: 14px; color: var(--primary);">
                                @if($role->slug === 'super_admin')
                                    Semua (100%)
                                @else
                                    {{ $role->permissions_count }} Permissions
                                @endif
                            </div>
                        </div>
                    </div>

                    <!-- Permission Badges Preview -->
                    <div style="display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 16px;">
                        @if($role->slug === 'super_admin')
                            <span style="font-size: 11px; background-color: #DEF7EC; color: #03543F; padding: 3px 8px; border-radius: 6px; font-weight: 600;">
                                &bull; Hak Akses Penuh ke Seluruh 20+ Modul & Endpoint
                            </span>
                        @else
                            @foreach($role->permissions->take(6) as $perm)
                                <span style="font-size: 11px; background-color: #E0F2FE; color: #0369A1; padding: 2px 8px; border-radius: 6px;">
                                    {{ $perm->name }}
                                </span>
                            @endforeach
                            @if($role->permissions->count() > 6)
                                <span style="font-size: 11px; background-color: var(--divider); color: var(--text-secondary); padding: 2px 8px; border-radius: 6px;">
                                    +{{ $role->permissions->count() - 6 }} lainnya
                                </span>
                            @endif
                        @endif
                    </div>
                </div>

                <div style="display: flex; justify-content: flex-end; gap: 8px; border-top: 1px solid var(--divider); padding-top: 14px;">
                    <a href="{{ route('admin.roles.edit', $role) }}" class="btn btn-outline btn-sm">
                        <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
                        Kelola Hak Akses
                    </a>
                    @if(!in_array($role->slug, ['super_admin', 'operator']))
                        <form action="{{ route('admin.roles.destroy', $role) }}" method="POST" onsubmit="return confirm('Hapus role {{ $role->name }}?');" style="display: inline;">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="btn btn-danger btn-sm">Hapus</button>
                        </form>
                    @endif
                </div>
            </div>
        @endforeach
    </div>
</div>
@endsection
