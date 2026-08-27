@extends('admin.layouts.app')

@section('title', 'Edit Tenant — Kasir Pro Admin')
@section('header_title', 'Edit Data Tenant')

@section('content')
    <div class="card" style="max-width: 600px; margin: 0 auto;">
        <div class="card-header">
            <h2 class="card-title">Form Data Tenant</h2>
        </div>
        <form action="{{ route('admin.tenants.update', $tenant->id) }}" method="POST">
            @csrf
            @method('PUT')
            <div class="form-group">
                <label class="form-label" for="name">Nama Bisnis / Perusahaan *</label>
                <input class="form-control" type="text" id="name" name="name" value="{{ old('name', $tenant->name) }}" required>
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="owner_name">Nama Pemilik (Owner) *</label>
                <input class="form-control" type="text" id="owner_name" name="owner_name" value="{{ old('owner_name', $tenant->owner_name) }}" required>
                @error('owner_name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="email">Email *</label>
                <input class="form-control" type="email" id="email" name="email" value="{{ old('email', $tenant->email) }}" required>
                @error('email') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="phone">Telepon / WhatsApp (Hanya Angka)</label>
                <input class="form-control" type="text" id="phone" name="phone" value="{{ old('phone', $tenant->phone) }}" oninput="this.value = this.value.replace(/[^0-9]/g, '')" pattern="[0-9]*">
                @error('phone') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="store_name">Nama Toko / Outlet</label>
                <input class="form-control" type="text" id="store_name" name="store_name" value="{{ old('store_name', $tenant->store_name) }}">
                @error('store_name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="store_address">Alamat Toko</label>
                <input class="form-control" type="text" id="store_address" name="store_address" value="{{ old('store_address', $tenant->store_address) }}">
                @error('store_address') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div style="margin-top: 24px; padding: 16px; background: var(--surface); border-radius: 12px; border: 1px solid var(--divider);">
                <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 6px; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
                    <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                    </svg>
                    Reset Password Akun Tenant (Opsional)
                </h3>
                <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 16px; line-height: 1.4;">
                    Biarkan kosong jika tidak ingin mengubah password akun login pengguna untuk tenant ini.
                </p>

                <div class="form-group">
                    <label class="form-label" for="password">Password Baru (New Password)</label>
                    <div style="position: relative;">
                        <input class="form-control" type="password" id="password" name="password" placeholder="Kosongkan jika tidak ingin mengubah" style="padding-right: 44px;">
                        <button type="button" onclick="togglePasswordVisibility('password', 'eye_icon_1')" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan Password">
                            <svg id="eye_icon_1" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                        </button>
                    </div>
                    @error('password') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label" for="password_confirmation">Konfirmasi Password Baru (Confirm New Password)</label>
                    <div style="position: relative;">
                        <input class="form-control" type="password" id="password_confirmation" name="password_confirmation" placeholder="Ulangi password baru" style="padding-right: 44px;">
                        <button type="button" onclick="togglePasswordVisibility('password_confirmation', 'eye_icon_2')" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan Password">
                            <svg id="eye_icon_2" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                        </button>
                    </div>
                </div>
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Perbarui Tenant</button>
            </div>
        </form>
    </div>

    @push('scripts')
    <script>
        function togglePasswordVisibility(fieldId, iconId) {
            const input = document.getElementById(fieldId);
            const icon = document.getElementById(iconId);
            if (!input || !icon) return;

            if (input.type === 'password') {
                input.type = 'text';
                icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />';
            } else {
                input.type = 'password';
                icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />';
            }
        }
    </script>
    @endpush
@endsection
