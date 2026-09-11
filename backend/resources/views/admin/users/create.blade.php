@extends('admin.layouts.app')

@section('title', 'Tambah Pengguna Baru')
@section('header_title', 'Tambah Pengguna')

@section('content')
<div style="max-width: 650px; margin: 0 auto;">
    <div class="card">
        <div class="card-header">
            <div>
                <h2 class="card-title">Form Tambah Admin Baru</h2>
                <p class="text-muted text-sm">Buat akun untuk staf atau administrator sistem.</p>
            </div>
            <a href="{{ route('admin.users.index') }}" class="btn btn-outline btn-sm">Kembali</a>
        </div>

        <form action="{{ route('admin.users.store') }}" method="POST">
            @csrf

            <div class="form-group">
                <label for="name" class="form-label">Nama Lengkap <span style="color: var(--error);">*</span></label>
                <input type="text" id="name" name="name" class="form-control" value="{{ old('name') }}" required autofocus placeholder="Contoh: Budi Santoso">
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label for="email" class="form-label">Alamat Email <span style="color: var(--error);">*</span></label>
                <input type="email" id="email" name="email" class="form-control" value="{{ old('email') }}" required placeholder="admin@possaas.com">
                @error('email') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="form-group">
                <label for="role_id" class="form-label">Role / Hak Akses <span style="color: var(--error);">*</span></label>
                <select id="role_id" name="role_id" class="form-control" required>
                    <option value="">-- Pilih Role --</option>
                    @foreach($roles as $role)
                        <option value="{{ $role->id }}" {{ old('role_id') == $role->id ? 'selected' : '' }}>
                            {{ $role->name }} &mdash; {{ $role->description }}
                        </option>
                    @endforeach
                </select>
                @error('role_id') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <div class="grid grid-2">
                <div class="form-group">
                    <label for="password" class="form-label">Password <span style="color: var(--error);">*</span></label>
                    <input type="password" id="password" name="password" class="form-control" required placeholder="Minimal 8 karakter">
                    @error('password') <div class="form-error">{{ $message }}</div> @enderror
                </div>
                <div class="form-group">
                    <label for="password_confirmation" class="form-label">Konfirmasi Password <span style="color: var(--error);">*</span></label>
                    <input type="password" id="password_confirmation" name="password_confirmation" class="form-control" required placeholder="Ulangi password">
                </div>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 16px;">
                <a href="{{ route('admin.users.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Simpan Pengguna</button>
            </div>
        </form>
    </div>
</div>
@endsection
