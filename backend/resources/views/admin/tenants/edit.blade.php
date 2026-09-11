@extends('admin.layouts.app')

@section('title', 'Edit Data Pelanggan — Kasir Pro Admin')
@section('header_title', 'Edit Data Pelanggan')

@section('content')
    <div class="card" style="max-width: 680px; margin: 0 auto;">
        <div class="card-header">
            <h2 class="card-title">Form Edit Data Pelanggan</h2>
        </div>
        <form action="{{ route('admin.tenants.update', $tenant->id) }}" method="POST">
            @csrf
            @method('PUT')

            <div class="form-group">
                <label class="form-label">Tipe Pelanggan *</label>
                <div style="display: flex; gap: 16px; margin-top: 6px;">
                    <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
                        <input type="radio" name="customer_type" value="individual" {{ old('customer_type', $tenant->customer_type) === 'individual' ? 'checked' : '' }} onchange="toggleTaxField(this.value)">
                        <span>Pribadi / Perorangan</span>
                    </label>
                    <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
                        <input type="radio" name="customer_type" value="company" {{ old('customer_type', $tenant->customer_type) === 'company' ? 'checked' : '' }} onchange="toggleTaxField(this.value)">
                        <span>Perusahaan / Badan Usaha</span>
                    </label>
                </div>
                @error('customer_type') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="grid grid-2">
                <div class="form-group">
                    <label class="form-label" for="name">Nama Pelanggan / Bisnis *</label>
                    <input class="form-control" type="text" id="name" name="name" value="{{ old('name', $tenant->name) }}" required>
                    @error('name') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group">
                    <label class="form-label" for="owner_name">Nama Pemilik / PIC *</label>
                    <input class="form-control" type="text" id="owner_name" name="owner_name" value="{{ old('owner_name', $tenant->owner_name) }}" required>
                    @error('owner_name') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            <div class="form-group" id="tax_number_group" style="display: {{ old('customer_type', $tenant->customer_type) === 'company' ? 'block' : 'none' }};">
                <label class="form-label" for="tax_number">NPWP (Nomor Pokok Wajib Pajak)</label>
                <input class="form-control" type="text" id="tax_number" name="tax_number" value="{{ old('tax_number', $tenant->tax_number) }}" placeholder="Contoh: 01.234.567.8-901.000">
                @error('tax_number') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="grid grid-2">
                <div class="form-group">
                    <label class="form-label" for="email">Email Login *</label>
                    <input class="form-control" type="email" id="email" name="email" value="{{ old('email', $tenant->email) }}" required>
                    @error('email') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group">
                    <label class="form-label" for="phone">Telepon / WhatsApp</label>
                    <input class="form-control" type="text" id="phone" name="phone" value="{{ old('phone', $tenant->phone) }}" oninput="this.value = this.value.replace(/[^0-9]/g, '')">
                    @error('phone') <div class="form-error">{{ $message }}</div> @enderror
                </div>
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

            <div class="grid grid-2">
                <div class="form-group">
                    <label class="form-label" for="city">Kota / Kabupaten</label>
                    <input class="form-control" type="text" id="city" name="city" value="{{ old('city', $tenant->city) }}">
                    @error('city') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group">
                    <label class="form-label" for="postal_code">Kode Pos</label>
                    <input class="form-control" type="text" id="postal_code" name="postal_code" value="{{ old('postal_code', $tenant->postal_code) }}">
                    @error('postal_code') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            <div style="margin-top: 24px; padding: 16px; background: var(--surface); border-radius: 12px; border: 1px solid var(--divider);">
                <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 6px; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
                    <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                    </svg>
                    Reset Password Akun Pelanggan (Opsional)
                </h3>
                <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 16px; line-height: 1.4;">
                    Biarkan kosong jika tidak ingin mengubah password akun login pengguna untuk pelanggan ini.
                </p>

                <div class="form-group">
                    <label class="form-label" for="password">Password Baru</label>
                    <div style="position: relative;">
                        <input class="form-control" type="password" id="password" name="password" placeholder="Kosongkan jika tidak ingin mengubah" style="padding-right: 44px;">
                        <button type="button" onclick="togglePasswordVisibility('password', 'eye_icon_1')" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan">
                            <svg id="eye_icon_1" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                        </button>
                    </div>
                    @error('password') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label" for="password_confirmation">Konfirmasi Password Baru</label>
                    <div style="position: relative;">
                        <input class="form-control" type="password" id="password_confirmation" name="password_confirmation" placeholder="Ulangi password baru" style="padding-right: 44px;">
                        <button type="button" onclick="togglePasswordVisibility('password_confirmation', 'eye_icon_2')" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan">
                            <svg id="eye_icon_2" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                        </button>
                    </div>
                </div>
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Perbarui Data Pelanggan</button>
            </div>
        </form>
    </div>
@endsection

@section('scripts')
<script>
    function toggleTaxField(type) {
        const group = document.getElementById('tax_number_group');
        if (type === 'company') {
            group.style.display = 'block';
        } else {
            group.style.display = 'none';
        }
    }

    function togglePasswordVisibility(fieldId, iconId) {
        const input = document.getElementById(fieldId);
        const icon = document.getElementById(iconId);
        if (input.type === 'password') {
            input.type = 'text';
            icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858-5.908a10.018 10.018 0 014.122-.963c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21M3 3l18 18" />`;
        } else {
            input.type = 'password';
            icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />`;
        }
    }
</script>
@endsection
