@extends('admin.layouts.app')

@section('title', 'Tambah Tenant Baru — POS SaaS')
@section('header_title', 'Tambah Tenant Baru')

@section('content')
    <div class="card" style="max-width: 650px; margin: 0 auto;">
        <div class="card-header">
            <h2 class="card-title">Form Data Tenant</h2>
        </div>
        <form action="{{ route('admin.tenants.store') }}" method="POST">
            @csrf
            <div class="form-group">
                <label class="form-label" for="name">Nama Bisnis / Perusahaan *</label>
                <input class="form-control" type="text" id="name" name="name" value="{{ old('name') }}" required placeholder="Contoh: CV Maju Bersama">
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="owner_name">Nama Pemilik (Owner) *</label>
                <input class="form-control" type="text" id="owner_name" name="owner_name" value="{{ old('owner_name') }}" required placeholder="Contoh: John Doe">
                @error('owner_name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="email">Email Kredensial (Login App) *</label>
                <input class="form-control" type="email" id="email" name="email" value="{{ old('email') }}" required placeholder="Contoh: owner@majubersama.com">
                @error('email') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="password">Password Kredensial (Login App) *</label>
                <div style="position: relative;">
                    <input class="form-control" type="password" id="password" name="password" required placeholder="Minimal 6 karakter" style="padding-right: 44px;">
                    <button type="button" onclick="togglePasswordVisibility()" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan Password">
                        <svg id="eye_icon" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        </svg>
                    </button>
                </div>
                @error('password') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="phone">Telepon / WhatsApp (Hanya Angka)</label>
                <input class="form-control" type="text" id="phone" name="phone" value="{{ old('phone') }}" placeholder="Contoh: 08123456789" oninput="this.value = this.value.replace(/[^0-9]/g, '')" pattern="[0-9]*">
                @error('phone') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="store_name">Nama Toko / Outlet</label>
                <input class="form-control" type="text" id="store_name" name="store_name" value="{{ old('store_name') }}" placeholder="Contoh: Kopi Maju Outlet 1">
                @error('store_name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label class="form-label" for="store_address">Alamat Toko</label>
                <input class="form-control" type="text" id="store_address" name="store_address" value="{{ old('store_address') }}" placeholder="Contoh: Jl. Diponegoro No. 12">
                @error('store_address') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group" style="background: var(--surface); padding: 16px; border-radius: 12px; border: 1px solid var(--divider);">
                <label class="form-label" for="package_id" style="font-weight: 600;">Pilih Paket SaaS *</label>
                <select class="form-control" id="package_id" name="package_id" required onchange="updatePackagePreview()">
                    <option value="">-- Pilih Paket --</option>
                    @foreach ($packages as $pkg)
                        <option value="{{ $pkg->id }}" 
                            data-price="{{ number_format($pkg->price, 0, ',', '.') }}"
                            data-validity="{{ $pkg->validity_type }}"
                            data-days="{{ $pkg->default_duration_days }}"
                            data-start="{{ $pkg->start_date ? $pkg->start_date->format('d M Y') : '' }}"
                            data-end="{{ $pkg->end_date ? $pkg->end_date->format('d M Y') : '' }}"
                            {{ old('package_id') == $pkg->id ? 'selected' : '' }}>
                            {{ $pkg->name }} — Rp {{ number_format($pkg->price, 0, ',', '.') }}
                        </option>
                    @endforeach
                </select>
                @error('package_id') <div class="form-error">{{ $message }}</div> @enderror

                <div id="package_preview" style="margin-top: 12px; display: none; padding: 12px; background: white; border-radius: 8px; border: 1px solid var(--divider);">
                    <div style="font-size: 13px; font-weight: 600; color: var(--primary);" id="preview_title"></div>
                    <div style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;" id="preview_detail"></div>
                </div>
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Simpan Tenant</button>
            </div>
        </form>
    </div>
@endsection

@section('scripts')
<script>
    function togglePasswordVisibility() {
        const input = document.getElementById('password');
        const icon = document.getElementById('eye_icon');
        
        if (input.type === 'password') {
            input.type = 'text';
            icon.innerHTML = `
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858-5.908a10.018 10.018 0 014.122-.963c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21M3 3l18 18" />
            `;
        } else {
            input.type = 'password';
            icon.innerHTML = `
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            `;
        }
    }

    function updatePackagePreview() {
        const select = document.getElementById('package_id');
        const preview = document.getElementById('package_preview');
        const title = document.getElementById('preview_title');
        const detail = document.getElementById('preview_detail');

        const option = select.options[select.selectedIndex];
        if (!option || !option.value) {
            preview.style.display = 'none';
            return;
        }

        const validity = option.getAttribute('data-validity');
        const days = option.getAttribute('data-days');
        const start = option.getAttribute('data-start');
        const end = option.getAttribute('data-end');
        const price = option.getAttribute('data-price');

        title.textContent = `Ringkasan Paket: ${option.text}`;
        
        let desc = `Harga: Rp ${price} | `;
        if (validity === 'date_range') {
            desc += `Metode: Range Waktu (${start || 'Sekarang'} s/d ${end || '-'})`;
        } else if (validity === 'fixed_date') {
            desc += `Metode: Berlaku s/d ${end || '-'}`;
        } else {
            desc += `Metode: Durasi (${days} hari sejak pendaftaran)`;
        }
        detail.textContent = desc;
        preview.style.display = 'block';
    }

    document.addEventListener('DOMContentLoaded', function() {
        updatePackagePreview();
    });
</script>
@endsection
