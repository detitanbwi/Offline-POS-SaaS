@extends('admin.layouts.app')

@section('title', 'Kelola Lisensi - POS SaaS')
@section('header_title', 'Daftar Lisensi Perangkat')

@section('content')
    <div class="grid grid-3">
        <!-- Form Generate Lisensi Baru -->
        <div class="card" style="grid-column: span 1; align-self: start;">
            <div class="card-header">
                <h2 class="card-title">Terbitkan Lisensi Baru</h2>
            </div>
            <form action="{{ route('admin.licenses.store') }}" method="POST">
                @csrf
                <div class="form-group">
                    <label class="form-label" for="tenant_id">Pilih Tenant</label>
                    <select name="tenant_id" id="tenant_id" class="form-control" required>
                        <option value="">-- Pilih Tenant --</option>
                        @foreach($tenants as $tenant)
                            <option value="{{ $tenant->id }}">{{ $tenant->name }} ({{ $tenant->owner_name }})</option>
                        @endforeach
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label" for="plan">Paket Subskripsi</label>
                    <select name="plan" id="plan" class="form-control" required>
                        <option value="trial">Trial (Masa Uji Coba)</option>
                        <option value="monthly">Monthly (Bulanan)</option>
                        <option value="yearly">Yearly (Tahunan)</option>
                        <option value="lifetime">Lifetime (Seumur Hidup)</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label" for="device_limit">Limit Jumlah Perangkat</label>
                    <input class="form-control" type="number" id="device_limit" name="device_limit" value="1" min="1" required>
                </div>

                <div class="form-group">
                    <label class="form-label" for="expires_in_days">Durasi Kustom (Hari) <span style="font-size: 11px; color: var(--text-secondary);">(Opsional)</span></label>
                    <input class="form-control" type="number" id="expires_in_days" name="expires_in_days" min="1" placeholder="Kosongkan jika mengikuti paket">
                </div>

                <button type="submit" class="btn btn-secondary" style="width: 100%; justify-content: center; margin-top: 12px;">+ Terbitkan Lisensi</button>
            </form>
        </div>

        <!-- Tabel List Lisensi -->
        <div class="card" style="grid-column: span 2;">
            <div class="card-header" style="flex-wrap: wrap; gap: 16px;">
                <h2 class="card-title">Semua Lisensi Terdaftar</h2>
                <form action="{{ route('admin.licenses.index') }}" method="GET" style="display: flex; gap: 12px; max-width: 400px; flex-grow: 1;">
                    <input type="text" name="search" class="form-control" placeholder="Cari lisensi key..." value="{{ request('search') }}">
                    <button type="submit" class="btn btn-primary">Cari</button>
                </form>
            </div>

            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Lisensi Key</th>
                            <th>Tenant</th>
                            <th>Paket</th>
                            <th>Limit Device</th>
                            <th>Berlaku Sampai</th>
                            <th>Status</th>
                            <th style="text-align: right;">Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($licenses as $license)
                            <tr>
                                <td>
                                    <a href="{{ route('admin.licenses.show', $license->id) }}" style="font-family: monospace; font-weight: 600; color: var(--primary);">{{ $license->license_key }}</a>
                                </td>
                                <td>
                                    @if($license->tenant)
                                        <a href="{{ route('admin.tenants.show', $license->tenant->id) }}" style="font-weight: 500;">{{ $license->tenant->name }}</a>
                                    @else
                                        <span style="color: var(--text-secondary); font-style: italic;">Tidak Ada</span>
                                    @endif
                                </td>
                                <td>
                                    @if($license->subscription)
                                        <span class="badge badge-info">{{ $license->subscription->plan }}</span>
                                    @else
                                        -
                                    @endif
                                </td>
                                <td>{{ $license->device_count }} / {{ $license->device_limit }}</td>
                                <td style="font-size: 13px;">{{ $license->expires_at->format('d/m/Y') }}</td>
                                <td>
                                    @if($license->status === 'ACTIVE')
                                        <span class="badge badge-success">Aktif</span>
                                    @elseif($license->status === 'AVAILABLE')
                                        <span class="badge badge-info">Tersedia</span>
                                    @elseif($license->status === 'EXPIRED')
                                        <span class="badge badge-warning">Kedaluwarsa</span>
                                    @else
                                        <span class="badge badge-danger">Ditangguhkan</span>
                                    @endif
                                </td>
                                <td style="text-align: right;">
                                    <div style="display: inline-flex; gap: 8px;">
                                        <a href="{{ route('admin.licenses.show', $license->id) }}" class="btn btn-outline btn-sm">Detail</a>
                                        @if($license->status !== 'REVOKED')
                                            <form action="{{ route('admin.licenses.suspend', $license->id) }}" method="POST" onsubmit="return confirm('Tangguhkan lisensi ini?')">
                                                @csrf
                                                <button type="submit" class="btn btn-danger btn-sm" style="background-color: var(--error);">Suspend</button>
                                            </form>
                                        @endif
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align: center; color: var(--text-secondary); padding: 32px;">Belum ada lisensi terbit.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top: 24px;">
                {{ $licenses->appends(request()->query())->links() }}
            </div>
        </div>
    </div>
@endsection
