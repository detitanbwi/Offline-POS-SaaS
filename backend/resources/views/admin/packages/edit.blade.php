@extends('admin.layouts.app')
@section('title', 'Edit Paket — Kasir Pro Admin')
@section('header_title', 'Edit Paket')

@section('content')
<div class="card">
    <form method="POST" action="{{ route('admin.packages.update', $package) }}">
        @csrf
        @method('PUT')
        
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

        <div class="grid grid-2">
            <div class="form-group">
                <label class="form-label">Harga (Rp) *</label>
                <input type="number" name="price" class="form-control" value="{{ old('price', $package->price) }}" min="0" step="1000" required>
                @error('price') <div class="form-error">{{ $message }}</div> @enderror
            </div>
            <div class="form-group">
                <label class="form-label">Device Limit / Token *</label>
                <input type="number" name="device_limit_per_token" class="form-control" value="{{ old('device_limit_per_token', $package->device_limit_per_token) }}" min="1" required>
                @error('device_limit_per_token') <div class="form-error">{{ $message }}</div> @enderror
            </div>
        </div>

        <div class="form-group" style="background: var(--surface); padding: 20px; border-radius: 12px; border: 1px solid var(--divider);">
            <label class="form-label" style="font-weight: 600; font-size: 15px; margin-bottom: 12px;">Metode Penentuan Masa Berlaku *</label>
            
            <div style="display: flex; gap: 20px; flex-wrap: wrap; margin-bottom: 16px;">
                <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 500;">
                    <input type="radio" name="validity_type" value="duration" {{ old('validity_type', $package->validity_type) == 'duration' ? 'checked' : '' }} onchange="toggleValidityFields()">
                    <span>Durasi (Pilihan Bulan / Tahun / Hari)</span>
                </label>
                <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 500;">
                    <input type="radio" name="validity_type" value="date_range" {{ old('validity_type', $package->validity_type) == 'date_range' ? 'checked' : '' }} onchange="toggleValidityFields()">
                    <span>Range Waktu (Dari Tanggal s/d Tanggal)</span>
                </label>
                <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 500;">
                    <input type="radio" name="validity_type" value="fixed_date" {{ old('validity_type', $package->validity_type) == 'fixed_date' ? 'checked' : '' }} onchange="toggleValidityFields()">
                    <span>Sampai Tanggal Tertentu</span>
                </label>
            </div>

            <!-- Option 1: Duration -->
            <div id="section_duration" class="validity-section" style="margin-top: 12px;">
                <div class="form-group">
                    <label class="form-label">Pilih Durasi Cepat</label>
                    <div style="display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 12px;">
                        <button type="button" class="btn btn-outline btn-sm" onclick="setPresetDays(90)">3 Bulan (90 Hari)</button>
                        <button type="button" class="btn btn-outline btn-sm" onclick="setPresetDays(180)">6 Bulan (180 Hari)</button>
                        <button type="button" class="btn btn-outline btn-sm" onclick="setPresetDays(365)">1 Tahun (365 Hari)</button>
                        <button type="button" class="btn btn-outline btn-sm" onclick="setPresetDays(730)">2 Tahun (730 Hari)</button>
                    </div>
                </div>
                <div class="form-group" style="max-width: 300px;">
                    <label class="form-label">Jumlah Durasi Hari *</label>
                    <input type="number" id="default_duration_days" name="default_duration_days" class="form-control" value="{{ old('default_duration_days', $package->default_duration_days) }}" min="1">
                    @error('default_duration_days') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            <!-- Option 2: Date Range -->
            <div id="section_date_range" class="validity-section" style="margin-top: 12px; display: none;">
                <div class="grid grid-2">
                    <div class="form-group">
                        <label class="form-label">Tanggal Mulai *</label>
                        <input type="date" id="start_date" name="start_date" class="form-control" value="{{ old('start_date', $package->start_date?->format('Y-m-d')) }}">
                        @error('start_date') <div class="form-error">{{ $message }}</div> @enderror
                    </div>
                    <div class="form-group">
                        <label class="form-label">Tanggal Selesai *</label>
                        <input type="date" id="end_date_range" name="end_date" class="form-control" value="{{ old('end_date', $package->end_date?->format('Y-m-d')) }}">
                        @error('end_date') <div class="form-error">{{ $message }}</div> @enderror
                    </div>
                </div>
            </div>

            <!-- Option 3: Fixed Date -->
            <div id="section_fixed_date" class="validity-section" style="margin-top: 12px; display: none;">
                <div class="form-group" style="max-width: 300px;">
                    <label class="form-label">Sampai Tanggal *</label>
                    <input type="date" id="end_date_fixed" name="end_date" class="form-control" value="{{ old('end_date', $package->end_date?->format('Y-m-d')) }}">
                    @error('end_date') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>
        </div>

        <div class="form-group">
            <label class="form-label">Deskripsi</label>
            <textarea name="description" class="form-control" rows="3">{{ old('description', $package->description) }}</textarea>
        </div>

        <div class="form-group" style="display:flex;align-items:center;gap:12px;margin-bottom:24px;">
            <label style="display:flex;align-items:center;gap:8px;cursor:pointer;">
                <input type="checkbox" name="is_active" value="1" {{ old('is_active', $package->is_active) ? 'checked' : '' }}>
                <span style="font-weight:500;">Status Aktif</span>
            </label>
        </div>

        <div style="display:flex;gap:12px;">
            <button type="submit" class="btn btn-primary">Simpan Perubahan</button>
            <a href="{{ route('admin.packages.index') }}" class="btn btn-outline">Batal</a>
        </div>
    </form>
</div>
@endsection

@section('scripts')
<script>
    function setPresetDays(days) {
        document.getElementById('default_duration_days').value = days;
    }

    function toggleValidityFields() {
        const type = document.querySelector('input[name="validity_type"]:checked')?.value || 'duration';
        
        document.getElementById('section_duration').style.display = (type === 'duration') ? 'block' : 'none';
        document.getElementById('section_date_range').style.display = (type === 'date_range') ? 'block' : 'none';
        document.getElementById('section_fixed_date').style.display = (type === 'fixed_date') ? 'block' : 'none';

        const endDateRange = document.getElementById('end_date_range');
        const endDateFixed = document.getElementById('end_date_fixed');
        if (type === 'date_range') {
            endDateRange.disabled = false;
            endDateFixed.disabled = true;
        } else if (type === 'fixed_date') {
            endDateRange.disabled = true;
            endDateFixed.disabled = false;
        } else {
            endDateRange.disabled = true;
            endDateFixed.disabled = true;
        }
    }

    document.addEventListener('DOMContentLoaded', function() {
        toggleValidityFields();
    });
</script>
@endsection
