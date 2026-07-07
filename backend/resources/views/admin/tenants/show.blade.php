@extends('admin.layouts.app')

@section('title', 'Detail Tenant — POS SaaS')
@section('header_title', 'Detail Informasi Tenant')

@section('content')
    <div class="grid grid-3">
        <!-- Informasi Utama Tenant -->
        <div class="card" style="grid-column: span 1;">
            <div class="card-header">
                <h2 class="card-title">Profil Tenant</h2>
                <a href="{{ route('admin.tenants.edit', $tenant->id) }}" class="btn btn-primary btn-sm">Edit</a>
            </div>
            
            <div style="display: flex; flex-direction: column; gap: 16px;">
                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">ID Tenant</label>
                    <code style="font-size: 13px;">{{ $tenant->id }}</code>
                </div>
                
                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Nama Bisnis</label>
                    <div style="font-weight: 600; font-size: 16px; color: var(--primary);">{{ $tenant->name }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Nama Owner</label>
                    <div style="font-weight: 500;">{{ $tenant->owner_name }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Kontak</label>
                    <div>Email: {{ $tenant->email }}</div>
                    <div>WhatsApp: {{ $tenant->phone ?? '-' }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Nama & Alamat Toko</label>
                    <div>Outlet: {{ $tenant->store_name ?? '-' }}</div>
                    <div style="font-size: 13px; color: var(--text-secondary);">{{ $tenant->store_address ?? '-' }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Status</label>
                    <div>
                        @if($tenant->status === 'active')
                            <span class="badge badge-success">Aktif</span>
                        @elseif($tenant->status === 'suspended')
                            <span class="badge badge-warning">Ditangguhkan</span>
                        @else
                            <span class="badge badge-danger">{{ $tenant->status }}</span>
                        @endif
                    </div>
                </div>
            </div>
        </div>

        <!-- Daftar Lisensi Tenant -->
        <div class="card" style="grid-column: span 2;">
            <div class="card-header">
                <h2 class="card-title">Daftar Lisensi Penerbitan</h2>
                <a href="{{ route('admin.licenses.index', ['search' => $tenant->name]) }}" class="btn btn-outline btn-sm">Lihat Semua Lisensi</a>
            </div>
            
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Lisensi Key</th>
                            <th>Masa Berlaku</th>
                            <th>Limit Perangkat</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($tenant->licenses as $license)
                            <tr>
                                <td>
                                    <a href="{{ route('admin.licenses.show', $license->id) }}" style="font-family: monospace; font-weight: 600; color: var(--primary);">{{ $license->license_key }}</a>
                                </td>
                                <td>{{ $license->expires_at->format('d/m/Y') }}</td>
                                <td>{{ $license->device_count }} / {{ $license->device_limit }} Perangkat</td>
                                <td>
                                    @if($license->status === 'ACTIVE')
                                        <span class="badge badge-success">Aktif</span>
                                    @elseif($license->status === 'AVAILABLE')
                                        <span class="badge badge-info">Tersedia</span>
                                    @else
                                        <span class="badge badge-danger">{{ $license->status }}</span>
                                    @endif
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" style="text-align: center; color: var(--text-secondary); padding: 24px;">Belum ada lisensi diterbitkan untuk tenant ini.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endsection
