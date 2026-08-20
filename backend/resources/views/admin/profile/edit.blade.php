@extends('admin.layouts.app')
@section('title', 'Edit Profil & Data Login - Kasir Pro Admin')
@section('header_title', 'Edit Profil & Data Login Administrator')

@section('content')
<div class="card" style="max-width: 700px; margin: 0 auto;">
    <div class="card-header">
        <h3 class="card-title">Pengaturan Akun & Kredensial Login</h3>
    </div>

    <form action="{{ route('admin.profile.update') }}" method="POST">
        @csrf
        @method('PUT')

        <div class="form-group">
            <label class="form-label" for="name">Nama Lengkap</label>
            <input type="text" name="name" id="name" class="form-control" value="{{ old('name', $user->name) }}" required>
            @error('name')
                <div class="form-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label class="form-label" for="email">Alamat Email (Username Login)</label>
            <input type="email" name="email" id="email" class="form-control" value="{{ old('email', $user->email) }}" required>
            @error('email')
                <div class="form-error">{{ $message }}</div>
            @enderror
        </div>

        <hr style="border: none; border-top: 1px solid var(--divider); margin: 24px 0;">

        <div style="margin-bottom: 16px;">
            <h4 style="font-size: 15px; font-weight: 600; color: var(--text-primary);">Identitas Penyedia Layanan Faktur (Pusat SaaS)</h4>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">Informasi ini akan tercetak sebagai Penyedia Layanan pada dokumen Faktur Lisensi PDF (Paid & Unpaid).</p>
        </div>

        <div class="form-group">
            <label class="form-label" for="company_name">Nama Perusahaan / Penyedia</label>
            <input type="text" name="company_name" id="company_name" class="form-control" value="{{ old('company_name', $providerSettings['company_name'] ?? '') }}" placeholder="Contoh: Wirodev Digital Architecture">
        </div>

        <div class="form-group">
            <label class="form-label" for="company_subtitle">Sub-deskripsi / Subtitle</label>
            <input type="text" name="company_subtitle" id="company_subtitle" class="form-control" value="{{ old('company_subtitle', $providerSettings['company_subtitle'] ?? '') }}" placeholder="Contoh: Pusat Pengembangan Sistem SaaS">
        </div>

        <div class="form-group">
            <label class="form-label" for="company_email">Email CS / Billing</label>
            <input type="email" name="company_email" id="company_email" class="form-control" value="{{ old('company_email', $providerSettings['company_email'] ?? '') }}" placeholder="Contoh: billing@wirodev.com">
        </div>

        <div class="form-group">
            <label class="form-label" for="company_phone">No. Telepon / WhatsApp CS (Opsional)</label>
            <input type="text" name="company_phone" id="company_phone" class="form-control" value="{{ old('company_phone', $providerSettings['company_phone'] ?? '') }}" placeholder="Contoh: +62 812-3456-7890">
        </div>

        <div class="form-group">
            <label class="form-label" for="company_address">Alamat Kantor (Opsional)</label>
            <input type="text" name="company_address" id="company_address" class="form-control" value="{{ old('company_address', $providerSettings['company_address'] ?? '') }}" placeholder="Contoh: Jakarta, Indonesia">
        </div>

        <hr style="border: none; border-top: 1px solid var(--divider); margin: 24px 0;">

        <div style="margin-bottom: 16px;">
            <h4 style="font-size: 15px; font-weight: 600; color: var(--text-primary);">Informasi Transfer Bank Faktur Tagihan (Unpaid)</h4>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">Informasi rekening bank tujuan pembayaran transfer yang tercetak pada Dokumen Faktur Tagihan.</p>
        </div>

        <div class="form-group">
            <label class="form-label" for="bank_name">Bank Tujuan</label>
            <input type="text" name="bank_name" id="bank_name" class="form-control" value="{{ old('bank_name', $providerSettings['bank_name'] ?? '') }}" placeholder="Contoh: Bank Mandiri">
        </div>

        <div class="form-group">
            <label class="form-label" for="bank_account_number">Nomor Rekening / Virtual Account</label>
            <input type="text" name="bank_account_number" id="bank_account_number" class="form-control" value="{{ old('bank_account_number', $providerSettings['bank_account_number'] ?? '') }}" placeholder="Contoh: 8899-0022-1133">
        </div>

        <div class="form-group">
            <label class="form-label" for="bank_account_holder">Atas Nama Rekening</label>
            <input type="text" name="bank_account_holder" id="bank_account_holder" class="form-control" value="{{ old('bank_account_holder', $providerSettings['bank_account_holder'] ?? '') }}" placeholder="Contoh: PT Wirodev Digital Architecture">
        </div>

        <hr style="border: none; border-top: 1px solid var(--divider); margin: 24px 0;">

        <div style="margin-bottom: 16px;">
            <h4 style="font-size: 15px; font-weight: 600; color: var(--text-primary);">Ubah Password Login (Opsional)</h4>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">Kosongkan jika tidak ingin mengubah password saat ini.</p>
        </div>

        <div class="form-group">
            <label class="form-label" for="current_password">Password Saat Ini</label>
            <input type="password" name="current_password" id="current_password" class="form-control" placeholder="••••••••">
            @error('current_password')
                <div class="form-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label class="form-label" for="password">Password Baru</label>
            <input type="password" name="password" id="password" class="form-control" placeholder="Minimal 8 karakter">
            @error('password')
                <div class="form-error">{{ $message }}</div>
            @enderror
        </div>

        <div class="form-group">
            <label class="form-label" for="password_confirmation">Konfirmasi Password Baru</label>
            <input type="password" name="password_confirmation" id="password_confirmation" class="form-control" placeholder="Ulangi password baru">
        </div>

        <div class="flex gap-3 mt-4" style="justify-content: flex-end;">
            <a href="{{ route('admin.dashboard') }}" class="btn btn-outline">Batal</a>
            <button type="submit" class="btn btn-primary">Simpan Perubahan</button>
        </div>
    </form>
</div>
@endsection
