@extends('admin.layouts.app')

@section('title', 'Tambah Role Baru')
@section('header_title', 'Tambah Role & Hak Akses')

@section('content')
<div style="max-width: 900px; margin: 0 auto;">
    <div class="card">
        <div class="card-header">
            <div>
                <h2 class="card-title">Buat Role Kustom Baru</h2>
                <p class="text-muted text-sm">Definisikan nama role dan tentukan hak akses granular yang diizinkan untuk staf.</p>
            </div>
            <a href="{{ route('admin.roles.index') }}" class="btn btn-outline btn-sm">Kembali</a>
        </div>

        <form action="{{ route('admin.roles.store') }}" method="POST">
            @csrf

            <div class="grid grid-2" style="margin-bottom: 24px;">
                <div class="form-group" style="margin-bottom: 0;">
                    <label for="name" class="form-label">Nama Role <span style="color: var(--error);">*</span></label>
                    <input type="text" id="name" name="name" class="form-control" value="{{ old('name') }}" placeholder="Contoh: Staff Keuangan / Customer Support" required autofocus>
                    @error('name') <div class="form-error">{{ $message }}</div> @enderror
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                    <label for="description" class="form-label">Deskripsi Singkat</label>
                    <input type="text" id="description" name="description" class="form-control" value="{{ old('description') }}" placeholder="Penjelasan tugas dan wewenang role">
                    @error('description') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; background-color: var(--surface); padding: 12px 16px; border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--divider);">
                <span style="font-size: 13px; font-weight: 600; color: var(--text-primary);">Pilih Hak Akses Granular:</span>
                <div style="display: flex; gap: 8px;">
                    <button type="button" class="btn btn-outline btn-xs" onclick="selectAll(true)">Centang Semua</button>
                    <button type="button" class="btn btn-outline btn-xs" onclick="selectAll(false)">Hapus Semua</button>
                </div>
            </div>

            <div style="display: flex; flex-direction: column; gap: 20px;">
                @php
                    $moduleLabels = [
                        'dashboard' => 'Modul Dashboard',
                        'tenants' => 'Modul Manajemen Tenant',
                        'packages' => 'Modul Paket Langganan',
                        'invoices' => 'Modul Tagihan & Invoice',
                        'subscriptions' => 'Modul Langganan',
                        'tokens' => 'Modul Token Lisensi',
                        'devices' => 'Modul Perangkat Kasir',
                        'users' => 'Modul Pengguna & RBAC',
                        'audit_logs' => 'Modul Audit Log',
                        'profile' => 'Modul Profil Admin',
                    ];
                @endphp

                @foreach($permissionsByModule as $module => $modulePermissions)
                    <div style="background-color: var(--surface); border: 1px solid var(--divider); border-radius: 14px; padding: 18px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--divider); padding-bottom: 8px;">
                            <h3 style="font-size: 14px; font-weight: 700; color: var(--primary);">
                                {{ $moduleLabels[$module] ?? 'Modul ' . ucfirst($module) }}
                            </h3>
                            <button type="button" class="btn btn-outline btn-xs" onclick="toggleModule('{{ $module }}')" style="font-size: 10px; padding: 2px 8px;">Pilih Semua</button>
                        </div>

                        <div class="grid grid-2" style="gap: 12px;">
                            @foreach($modulePermissions as $perm)
                                @php
                                    $isChecked = is_array(old('permissions')) && in_array($perm->id, old('permissions'));
                                @endphp
                                <label style="display: flex; align-items: flex-start; gap: 10px; background-color: var(--card); padding: 12px; border-radius: 10px; border: 1px solid var(--divider); cursor: pointer;">
                                    <input type="checkbox" name="permissions[]" value="{{ $perm->id }}" class="perm-checkbox perm-module-{{ $module }}" {{ $isChecked ? 'checked' : '' }} style="margin-top: 3px; width: 16px; height: 16px; accent-color: var(--primary);">
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
                <button type="submit" class="btn btn-primary">Simpan Role Baru</button>
            </div>
        </form>
    </div>
</div>

<script>
    function selectAll(check) {
        document.querySelectorAll('.perm-checkbox').forEach(cb => {
            cb.checked = check;
        });
    }

    function toggleModule(module) {
        const checkboxes = document.querySelectorAll('.perm-module-' + module);
        const allChecked = Array.from(checkboxes).every(cb => cb.checked);
        checkboxes.forEach(cb => {
            cb.checked = !allChecked;
        });
    }
</script>
@endsection
