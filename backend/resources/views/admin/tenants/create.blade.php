@extends('admin.layouts.app')

@section('title', 'Tambah Tenant Baru — POS SaaS')
@section('header_title', 'Tambah Tenant Baru')

@section('content')
    <div class="card" style="max-width: 600px; margin: 0 auto;">
        <div class="card-header">
            <h2 class="card-title">Form Data Tenant</h2>
        </div>
        <form action="{{ route('admin.tenants.store') }}" method="POST">
            @csrf
            <div class="form-group">
                <label class="form-label" for="name">Nama Bisnis / Perusahaan</label>
                <input class="form-control" type="text" id="name" name="name" required placeholder="Contoh: CV Maju Bersama">
            </div>

            <div class="form-group">
                <label class="form-label" for="owner_name">Nama Pemilik (Owner)</label>
                <input class="form-control" type="text" id="owner_name" name="owner_name" required placeholder="Contoh: John Doe">
            </div>

            <div class="form-group">
                <label class="form-label" for="email">Email</label>
                <input class="form-control" type="email" id="email" name="email" required placeholder="Contoh: owner@majubersama.com">
            </div>

            <div class="form-group">
                <label class="form-label" for="phone">Telepon / WhatsApp</label>
                <input class="form-control" type="text" id="phone" name="phone" placeholder="Contoh: 08123456789">
            </div>

            <div class="form-group">
                <label class="form-label" for="store_name">Nama Toko / Outlet</label>
                <input class="form-control" type="text" id="store_name" name="store_name" placeholder="Contoh: Kopi Maju Outlet 1">
            </div>

            <div class="form-group">
                <label class="form-label" for="store_address">Alamat Toko</label>
                <input class="form-control" type="text" id="store_address" name="store_address" placeholder="Contoh: Jl. Diponegoro No. 12">
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary">Simpan Tenant</button>
            </div>
        </form>
    </div>
@endsection
