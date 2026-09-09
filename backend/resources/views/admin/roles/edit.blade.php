@extends('admin.layouts.app')

@section('title', 'Kelola Hak Akses Role: ' . $role->name)
@section('header_title', 'Matriks Hak Akses Granular')

@section('content')
<div style="max-width: 900px; margin: 0 auto;">
    <div class="card">
        <div class="card-header">
            <div>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <h2 class="card-title">Matriks Hak Akses: {{ $role->name }}</h2>
                    @if($role->slug === 'super_admin')
                        <span class="badge badge-success">Super Admin (All Wewenang)</span>
                    @elseif($role->slug === 'operator')
                        <span class="badge badge-warning">Operator</span>
                    @else
                        <span class="badge badge-info">Custom Role</span>
                    @endif
                </div>
                <p class="text-muted text-sm">Centang hak akses spesifik yang diizinkan untuk tingkatan pengguna role ini.</p>
            </div>
            <a href="{{ route('admin.roles.index') }}" class="btn btn-outline btn-sm">Kembali</a>
        </div>

        <form action="{{ route('admin.roles.update', $role) }}" method="POST">
            @csrf
            @method('PUT')

            <div class="grid grid-2" style="margin-bottom: 24px;">
                <div class="form-group" style="margin-bottom: 0;">
                    <label for="name" class="form-label">Nama Role <span style="color: var(--error);">*</span></label>
                    <input type="text" id="name" name="name" class="form-control" value="{{ old('name', $role->name) }}" required {{ in_array($role->slug, ['super_admin', 'operator']) ? 'readonly' : '' }}>
                    @error('name') <div class="form-error">{{ $message }}</div> @enderror
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                    <label for="description" class="form-label">Deskripsi Singkat</label>
                    <input type="text" id="description" name="description" class="form-control" value="{{ old('description', $role->description) }}" placeholder="Penjelasan tugas dan batas wewenang role">
                    @error('description') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            @if($role->slug === 'super_admin')
                <div class="alert alert-success" style="margin-bottom: 24px;">
                    <strong>Role Super Admin:</strong> Memiliki wewenang 100% penuh atas seluruh sistem dan bypass semua otorisasi (seluruh modul selalu aktif).
                </div>
            @else
                <div style="display: flex; justify-content: space-between; align-items: center; background-color: var(--surface); padding: 12px 16px; border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--divider);">
                    <span style="font-size: 13px; font-weight: 600; color: var(--text-primary);">Pilih Cepat Granular:</span>
                    <div style="display: flex; gap: 8px;">
                        <button type="button" class="btn btn-outline btn-xs" onclick="selectAll(true)">Centang Semua</button>
                        <button type="button" class="btn btn-outline btn-xs" onclick="selectAll(false)">Hapus Semua</button>
                    </div>
                </div>
            @endif

            <div style="display: flex; flex-direction: column; gap: 20px;">
                @php
                    $moduleLabels = [
                        'dashboard' => '📊 Modul Dashboard',
                        'tenants' => '🏢 Modul Manajemen Tenant',
                        'packages' => '📦 Modul Paket Langganan',
                        'invoices' => '🧾 Modul Tagihan & Invoice',
                        'subscriptions' => '🔄 Modul Langganan',
                        'tokens' => '🔑 Modul Token Lisensi',
                        'devices' => '📱 Modul Perangkat Kasir',
                        'users' => '👥 Modul Pengguna & RBAC',
                        'audit_logs' => '📋 Modul Audit Log',
                        'profile' => '⚙️ Modul Profil Admin',
                    ];
                @endphp

                @foreach($permissionsByModule as $module => $modulePermissions)
                    <div style="background-color: var(--surface); border: 1px solid var(--divider); border-radius: 14px; padding: 18px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--divider); padding-bottom: 8px;">
                            <h3 style="font-size: 14px; font-weight: 700; color: var(--primary);">
                                {{ $moduleLabels[$module] ?? 'Modul ' . ucfirst($module) }}
                            </h3>
                            @if($role->slug !== 'super_admin')
                                <button type="button" class="btn btn-outline btn-xs" onclick="toggleModule('{{ $module }}')" style="font-size: 10px; padding: 2px 8px;">Toggle Modul</button>
                            @endif
                        </div>

                        <div class="grid grid-2" style="gap: 12px;">
                            @foreach($modulePermissions as $perm)
                                @php
                                    $isChecked = in_array($perm->id, old('permissions', $rolePermissionIds)) || $role->slug === 'super_admin';
                                @endphp
                                <label style="display: flex; align-items: flex-start; gap: 10px; background-color: var(--card); padding: 12px; border-radius: 10px; border: 1px solid var(--divider); cursor: pointer; transition: all 0.2s;">
                                    <input type="checkbox" name="permissions[]" value="{{ $perm->id }}" class="perm-checkbox perm-module-{{ $module }}" {{ $isChecked ? 'checked' : '' }} {{ $role->slug === 'super_admin' ? 'disabled checked' : '' }} style="margin-top: 3px; width: 16px; height: 16px; accent-color: var(--primary);">
                                    <div style="line-height: 1.3;">
                                        <div style="font-size: 13px; font-weight: 600; color: var(--text-primary);">
                                            {{ $perm->name }}
                                        </div>
                                        <div class="text-muted text-xs" style="margin-top: 2px;">
                                            {{ $perm->description }}
                                        </div>
                                        <div class="font-mono" style="font-size: 10px; color: var(--disabled); margin-top: 4px;">
                                            <code>{{ $perm->slug }}</code>
                                        </div>
                                    </div>
                                </label>
                            @endforeach
                        </div>
                    </div>
                @endforeach
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--divider);">
                <a href="{{ route('admin.roles.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Simpan Hak Akses</button>
            </div>
        </form>
    </div>
</div>

<script>
    function selectAll(check) {
        document.querySelectorAll('.perm-checkbox').forEach(cb => {
            if (!cb.disabled) cb.checked = check;
        });
    }

    function toggleModule(module) {
        const checkboxes = document.querySelectorAll('.perm-module-' + module);
        const allChecked = Array.from(checkboxes).every(cb => cb.checked);
        checkboxes.forEach(cb => {
            if (!cb.disabled) cb.checked = !allChecked;
        });
    }
</script>
@endsection
