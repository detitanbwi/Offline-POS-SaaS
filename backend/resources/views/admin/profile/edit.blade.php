@extends('admin.layouts.app')
@section('title', 'Edit Profil & Data Login - POS SaaS Admin')
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
