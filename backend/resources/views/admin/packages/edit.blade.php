@extends('admin.layouts.app')
@section('title', 'Edit Paket — POS SaaS Admin')
@section('header_title', 'Edit Paket')

@section('content')
<div class="card">
    <form method="POST" action="{{ route('admin.packages.update', $package) }}">
        @csrf @method('PUT')
        <div class="grid grid-2">
            <div class="form-group">
                <label class="form-label">Nama Paket *</label>
                <input type="text" name="name" class="form-control" value="{{ old('name', $package->name) }}" required>
                @error('name') <div class="form-error">{{ $message }}</div> @enderror
            </div>
            <div class="form-group">
                <label class="form-label">Slug</label>
                <input type="text" name="slug" class="form-control" value="{{ old('slug', $package->slug) }}">
                @error('slug') <div class="form-error">{{ $message }}</div> @enderror
            </div>
        </div>
        <div class="grid grid-3">
            <div class="form-group">
                <label class="form-label">Harga (Rp) *</label>
                <input type="number" name="price" class="form-control" value="{{ old('price', $package->price) }}" min="0" step="1000" required>
            </div>
            <div class="form-group">
                <label class="form-label">Durasi Default (hari) *</label>
                <input type="number" name="default_duration_days" class="form-control" value="{{ old('default_duration_days', $package->default_duration_days) }}" min="1" required>
            </div>
            <div class="form-group">
                <label class="form-label">Device Limit / Token *</label>
                <input type="number" name="device_limit_per_token" class="form-control" value="{{ old('device_limit_per_token', $package->device_limit_per_token) }}" min="1" required>
            </div>
        </div>
        <div class="form-group">
            <label class="form-label">Deskripsi</label>
            <textarea name="description" class="form-control" rows="3">{{ old('description', $package->description) }}</textarea>
        </div>
        <div class="grid grid-2">
            <div class="form-group">
                <label class="form-label">Urutan Tampil</label>
                <input type="number" name="sort_order" class="form-control" value="{{ old('sort_order', $package->sort_order) }}" min="0">
            </div>
            <div class="form-group" style="display:flex;align-items:end;gap:12px;padding-bottom:20px;">
                <label><input type="checkbox" name="is_active" value="1" {{ old('is_active', $package->is_active) ? 'checked' : '' }}> Aktif</label>
            </div>
        </div>
        <div style="display:flex;gap:12px;">
            <button type="submit" class="btn btn-primary">Simpan Perubahan</button>
            <a href="{{ route('admin.packages.index') }}" class="btn btn-outline">Batal</a>
        </div>
    </form>
</div>
@endsection
