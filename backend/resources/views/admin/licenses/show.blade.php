@extends('admin.layouts.app')

@section('title', 'Detail Lisensi - Kasir Pro Admin')
@section('header_title', 'Detail Informasi Lisensi')

@section('content')
    <div class="grid grid-3">
        <!-- Detail Lisensi -->
        <div class="card" style="grid-column: span 1;">
            <div class="card-header">
                <h2 class="card-title">Profil Lisensi</h2>
            </div>
            
            <div style="display: flex; flex-direction: column; gap: 16px;">
                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Lisensi Key</label>
                    <code style="font-size: 16px; font-weight: 700; color: var(--primary);">{{ $license->license_key }}</code>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Tenant</label>
                    @if($license->tenant)
                        <div style="font-weight: 500;">
                            <a href="{{ route('admin.tenants.show', $license->tenant->id) }}">{{ $license->tenant->name }}</a>
                        </div>
                    @else
                        <div style="color: var(--text-secondary); font-style: italic;">Tidak terikat tenant</div>
                    @endif
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Limit Perangkat</label>
                    <div>{{ $license->device_count }} terdaftar dari maks {{ $license->device_limit }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Berlaku Sampai</label>
                    <div>{{ $license->expires_at->format('d/m/Y H:i') }}</div>
                </div>

                <div>
                    <label class="form-label" style="color: var(--text-secondary); font-size: 12px; margin-bottom: 2px;">Status</label>
                    <div>
                        @if($license->status === 'ACTIVE')
                            <span class="badge badge-success">Aktif</span>
                        @elseif($license->status === 'AVAILABLE')
                            <span class="badge badge-info">Tersedia</span>
                        @elseif($license->status === 'EXPIRED')
                            <span class="badge badge-warning">Kedaluwarsa</span>
                        @else
                            <span class="badge badge-danger">Ditangguhkan</span>
                        @endif
                    </div>
                </div>
            </div>

            <!-- Form Perpanjang Lisensi -->
            <div style="margin-top: 32px; border-top: 1px solid var(--divider); padding-top: 24px;">
                <h3 style="font-size: 14px; font-weight: 600; margin-bottom: 16px;">Perpanjang Lisensi</h3>
                <form action="{{ route('admin.licenses.renew', $license->id) }}" method="POST">
                    @csrf
                    <div class="form-group">
                        <label class="form-label" for="plan">Pilih Paket Baru</label>
                        <select name="plan" id="plan" class="form-control" required>
                            <option value="monthly">Monthly (+30 Hari)</option>
                            <option value="yearly">Yearly (+365 Hari)</option>
                            <option value="lifetime">Lifetime</option>
                        </select>
                    </div>
                    <button type="submit" class="btn btn-secondary btn-sm" style="width: 100%; justify-content: center;">Perbarui Masa Aktif</button>
                </form>
            </div>
        </div>

        <!-- Daftar Perangkat Terikat -->
        <div class="card" style="grid-column: span 2;">
            <div class="card-header">
                <h2 class="card-title">Perangkat Terikat (Device Binding)</h2>
            </div>
            
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Model / Brand</th>
                            <th>Fingerprint Hash</th>
                            <th>Waktu Aktivasi</th>
                            <th>Validasi Terakhir</th>
                            <th>Status</th>
                            <th style="text-align: right;">Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($license->devices as $device)
                            <tr>
                                <td>
                                    <strong>{{ $device->device_model }}</strong>
                                    <div style="font-size: 12px; color: var(--text-secondary);">Brand: {{ $device->device_brand }}</div>
                                </td>
                                <td>
                                    <code title="{{ $device->fingerprint_hash }}" style="cursor: help;">
                                        {{ substr($device->fingerprint_hash, 0, 8) }}...{{ substr($device->fingerprint_hash, -8) }}
                                    </code>
                                </td>
                                <td style="font-size: 13px;">{{ $device->activated_at->format('d/m/Y H:i') }}</td>
                                <td style="font-size: 13px;">{{ $device->last_validated_at ? $device->last_validated_at->format('d/m/Y H:i') : '-' }}</td>
                                <td>
                                    @if($device->status === 'active')
                                        <span class="badge badge-success">Aktif</span>
                                    @else
                                        <span class="badge badge-danger">Dihapus</span>
                                    @endif
                                </td>
                                <td style="text-align: right;">
                                    @if($device->status === 'active')
                                        <form action="{{ route('admin.licenses.reset-device', [$license->id, $device->id]) }}" method="POST" onsubmit="return confirm('Reset perangkat ini? Tindakan ini akan membebaskan slot lisensi.')">
                                            @csrf
                                            <button type="submit" class="btn btn-danger btn-sm" style="background-color: var(--error);">Reset Device</button>
                                        </form>
                                    @else
                                        -
                                    @endif
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="6" style="text-align: center; color: var(--text-secondary); padding: 32px;">Belum ada perangkat terikat untuk lisensi ini.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endsection
