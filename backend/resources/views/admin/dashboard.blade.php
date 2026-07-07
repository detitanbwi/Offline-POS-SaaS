@extends('admin.layouts.app')

@section('title', 'Dashboard Admin — POS SaaS')
@section('header_title', 'Dashboard Ringkasan')

@section('content')
    <div class="grid grid-4" style="margin-bottom: 32px;">
        <div class="card" style="padding: 20px; display: flex; flex-direction: column; justify-content: space-between; min-height: 120px; margin-bottom: 0;">
            <span style="font-size: 13px; color: var(--text-secondary); font-weight: 500;">Total Tenant</span>
            <span style="font-size: 28px; font-weight: 700; color: var(--primary); margin-top: 8px;">{{ $stats['total_tenants'] }}</span>
            <span style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">{{ $stats['active_tenants'] }} Aktif</span>
        </div>
        
        <div class="card" style="padding: 20px; display: flex; flex-direction: column; justify-content: space-between; min-height: 120px; margin-bottom: 0;">
            <span style="font-size: 13px; color: var(--text-secondary); font-weight: 500;">Lisensi Terbit</span>
            <span style="font-size: 28px; font-weight: 700; color: var(--primary); margin-top: 8px;">{{ $stats['total_licenses'] }}</span>
            <span style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">{{ $stats['active_licenses'] }} Aktif</span>
        </div>

        <div class="card" style="padding: 20px; display: flex; flex-direction: column; justify-content: space-between; min-height: 120px; margin-bottom: 0;">
            <span style="font-size: 13px; color: var(--text-secondary); font-weight: 500;">Perangkat Perizinan</span>
            <span style="font-size: 28px; font-weight: 700; color: var(--primary); margin-top: 8px;">{{ $stats['total_devices'] }}</span>
            <span style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">Terikat ke Lisensi</span>
        </div>

        <div class="card" style="padding: 20px; display: flex; flex-direction: column; justify-content: space-between; min-height: 120px; margin-bottom: 0;">
            <span style="font-size: 13px; color: var(--text-secondary); font-weight: 500;">Default Trial</span>
            <span style="font-size: 28px; font-weight: 700; color: var(--secondary); margin-top: 8px;">{{ $defaultTrialDays }} Hari</span>
            <span style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">Masa Uji Coba Gratis</span>
        </div>
    </div>

    <div class="grid grid-3">
        <!-- Pengaturan Global Sistem -->
        <div class="card" style="grid-column: span 1;">
            <div class="card-header">
                <h2 class="card-title">Pengaturan Sistem</h2>
            </div>
            <form action="{{ route('admin.settings.update') }}" method="POST">
                @csrf
                <div class="form-group">
                    <label class="form-label" for="default_trial_days">Durasi Trial Default (Hari)</label>
                    <input class="form-control" type="number" id="default_trial_days" name="default_trial_days" value="{{ $defaultTrialDays }}" min="1" required>
                </div>
                <button type="submit" class="btn btn-primary" style="width: 100%; justify-content: center;">Simpan Pengaturan</button>
            </form>
        </div>

        <!-- Aktivitas Terbaru Audit Log -->
        <div class="card" style="grid-column: span 2;">
            <div class="card-header">
                <h2 class="card-title">Log Aktivitas Keamanan Terbaru</h2>
                <a href="{{ route('admin.audit-logs.index') }}" class="btn btn-outline btn-sm">Lihat Semua</a>
            </div>
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Waktu</th>
                            <th>Aksi</th>
                            <th>Rincian</th>
                            <th>IP Address</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($stats['recent_activities'] as $activity)
                            <tr>
                                <td style="white-space: nowrap; font-size: 12px;">{{ $activity->created_at->format('d/m/Y H:i') }}</td>
                                <td><span class="badge badge-info">{{ $activity->action }}</span></td>
                                <td style="max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">{{ $activity->details }}</td>
                                <td><code>{{ $activity->ip_address }}</code></td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" style="text-align: center; color: var(--text-secondary);">Belum ada log aktivitas.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endsection
