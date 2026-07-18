@extends('admin.layouts.app')
@section('title', 'Tambah Paket — POS SaaS Admin')
@section('header_title', 'Tambah Paket Baru')

@section('content')
<div class="card">
    <form method="POST" action="{{ route('admin.packages.store') }}">
        @csrf
        <div class="grid grid-2">
            <div class="form-group">
                <label class="form-label">Nama Paket *</label>
                <input type="text" name="name" class="form-control" value="{{ old('name') }}" required>
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>
            <div class="form-group">
                <label class="form-label">Slug (otomatis jika kosong)</label>
                <input type="text" name="slug" class="form-control" value="{{ old('slug') }}" placeholder="basic-package">
                @error('slug') <div class="form-error">{{ $message }}</div> @enderror
            </div>
        </div>
        <div class="grid grid-3">
            <div class="form-group">
                <label class="form-label">Harga (Rp) *</label>
                <input type="number" name="price" class="form-control" value="{{ old('price', 0) }}" min="0" step="1000" required>
                @error('price') <div class="form-error">{{ $message }}</div> @enderror
            </div>
            <div class="form-group">
                <label class="form-label">Durasi Default (hari) *</label>
                <input type="number" name="default_duration_days" class="form-control" value="{{ old('default_duration_days', 30) }}" min="1" required>
            </div>
            <div class="form-group">
                <label class="form-label">Device Limit / Token *</label>
                <input type="number" name="device_limit_per_token" class="form-control" value="{{ old('device_limit_per_token', 1) }}" min="1" required>
            </div>
        </div>
        <div class="form-group">
            <label class="form-label">Deskripsi</label>
            <textarea name="description" class="form-control" rows="3">{{ old('description') }}</textarea>
        </div>
        <div class="grid grid-2">
            <div class="form-group">
                <label class="form-label">Urutan Tampil</label>
                <input type="number" name="sort_order" class="form-control" value="{{ old('sort_order', 0) }}" min="0">
            </div>
            <div class="form-group" style="display:flex;align-items:end;gap:12px;padding-bottom:20px;">
                <label><input type="checkbox" name="is_active" value="1" {{ old('is_active', true) ? 'checked' : '' }}> Aktif</label>
            </div>
        </div>
        <div style="display:flex;gap:12px;">
            <button type="submit" class="btn btn-primary">Simpan Paket</button>
            <a href="{{ route('admin.packages.index') }}" class="btn btn-outline">Batal</a>
        </div>
    </form>
</div>
@endsection
