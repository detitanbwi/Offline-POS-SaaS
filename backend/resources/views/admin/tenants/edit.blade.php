@extends('admin.layouts.app')

@section('title', 'Edit Tenant — POS SaaS')
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
                <label class="form-label" for="name">Nama Bisnis / Perusahaan</label>
                <input class="form-control" type="text" id="name" name="name" value="{{ old('name', $tenant->name) }}" required>
            </div>

            <div class="form-group">
                <label class="form-label" for="owner_name">Nama Pemilik (Owner)</label>
                <input class="form-control" type="text" id="owner_name" name="owner_name" value="{{ old('owner_name', $tenant->owner_name) }}" required>
            </div>

            <div class="form-group">
                <label class="form-label" for="email">Email</label>
                <input class="form-control" type="email" id="email" name="email" value="{{ old('email', $tenant->email) }}" required>
            </div>

            <div class="form-group">
                <label class="form-label" for="phone">Telepon / WhatsApp</label>
                <input class="form-control" type="text" id="phone" name="phone" value="{{ old('phone', $tenant->phone) }}">
            </div>

            <div class="form-group">
                <label class="form-label" for="store_name">Nama Toko / Outlet</label>
                <input class="form-control" type="text" id="store_name" name="store_name" value="{{ old('store_name', $tenant->store_name) }}">
            </div>

            <div class="form-group">
                <label class="form-label" for="store_address">Alamat Toko</label>
                <input class="form-control" type="text" id="store_address" name="store_address" value="{{ old('store_address', $tenant->store_address) }}">
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Perbarui Tenant</button>
            </div>
        </form>
    </div>
@endsection
