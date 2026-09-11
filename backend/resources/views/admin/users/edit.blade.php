@extends('admin.layouts.app')

@section('title', 'Edit Pengguna')
@section('header_title', 'Edit Pengguna')

@section('content')
<div style="max-width: 650px; margin: 0 auto;">
    <div class="card">
        <div class="card-header">
            <div>
                <h2 class="card-title">Edit Data Pengguna: {{ $user->name }}</h2>
                <p class="text-muted text-sm">Perbarui profil, role, atau ubah password pengguna.</p>
            </div>
            <a href="{{ route('admin.users.index') }}" class="btn btn-outline btn-sm">Kembali</a>
        </div>

        <form action="{{ route('admin.users.update', $user) }}" method="POST">
            @csrf
            @method('PUT')

            <div class="form-group">
                <label for="name" class="form-label">Nama Lengkap <span style="color: var(--error);">*</span></label>
                <input type="text" id="name" name="name" class="form-control" value="{{ old('name', $user->name) }}" required autofocus>
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label for="email" class="form-label">Alamat Email <span style="color: var(--error);">*</span></label>
                <input type="email" id="email" name="email" class="form-control" value="{{ old('email', $user->email) }}" required>
                @error('email') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label for="role_id" class="form-label">Role / Hak Akses <span style="color: var(--error);">*</span></label>
                <select id="role_id" name="role_id" class="form-control" required>
                    @foreach($roles as $role)
                        <option value="{{ $role->id }}" {{ old('role_id', $user->role_id) == $role->id ? 'selected' : '' }}>
                            {{ $role->name }} &mdash; {{ $role->description }}
                        </option>
                    @endforeach
                </select>
                @error('role_id') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div style="background-color: var(--surface); border: 1px solid var(--divider); border-radius: 12px; padding: 16px; margin: 20px 0;">
                <p style="font-size: 13px; font-weight: 600; margin-bottom: 8px; color: var(--text-primary);">Ubah Password (Opsional)</p>
                <p class="text-muted text-xs" style="margin-bottom: 12px;">Biarkan kosong jika tidak ingin mengubah password.</p>

                <div class="grid grid-2">
                    <div class="form-group" style="margin-bottom: 0;">
                        <label for="password" class="form-label">Password Baru</label>
                        <input type="password" id="password" name="password" class="form-control" placeholder="Minimal 8 karakter">
                        @error('password') <div class="form-error">{{ $message }}</div> @enderror
                    </div>
                    <div class="form-group" style="margin-bottom: 0;">
                        <label for="password_confirmation" class="form-label">Konfirmasi Password</label>
                        <input type="password" id="password_confirmation" name="password_confirmation" class="form-control" placeholder="Ulangi password baru">
                    </div>
                </div>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 16px;">
                <a href="{{ route('admin.users.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Simpan Perubahan</button>
            </div>
        </form>
    </div>
</div>
@endsection
