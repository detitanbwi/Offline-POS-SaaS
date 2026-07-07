@extends('admin.layouts.app')

@section('title', 'Audit Log Keamanan — POS SaaS')
@section('header_title', 'Audit Log Keamanan')

@section('content')
    <div class="card">
        <div class="card-header" style="flex-wrap: wrap; gap: 16px;">
            <h2 class="card-title">Aktivitas Audit Keamanan Sistem</h2>
            <form action="{{ route('admin.audit-logs.index') }}" method="GET" style="display: flex; gap: 12px; max-width: 600px; flex-grow: 1;">
                <select name="action" class="form-control" style="width: 180px;">
                    <option value="">Semua Aksi</option>
                    <option value="login" {{ request('action') === 'login' ? 'selected' : '' }}>Login</option>
                    <option value="device_activation" {{ request('action') === 'device_activation' ? 'selected' : '' }}>Aktivasi Perangkat</option>
                    <option value="license_validation" {{ request('action') === 'license_validation' ? 'selected' : '' }}>Validasi Lisensi</option>
                    <option value="device_reset" {{ request('action') === 'device_reset' ? 'selected' : '' }}>Reset Perangkat</option>
                    <option value="license_generate" {{ request('action') === 'license_generate' ? 'selected' : '' }}>Generate Lisensi</option>
                </select>
                <input type="text" name="search" class="form-control" placeholder="Cari log detail..." value="{{ request('search') }}">
                <button type="submit" class="btn btn-primary">Filter</button>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>Waktu</th>
                        <th>Aksi</th>
                        <th>Tenant</th>
                        <th>Rincian Aktivitas</th>
                        <th>Pengguna</th>
                        <th>IP / User Agent</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($logs as $log)
                        <tr>
                            <td style="white-space: nowrap; font-size: 13px;">{{ $log->created_at->format('d/m/Y H:i:s') }}</td>
                            <td>
                                @if(in_array($log->action, ['device_activation', 'license_generate']))
                                    <span class="badge badge-success">{{ $log->action }}</span>
                                @elseif($log->action === 'device_reset')
                                    <span class="badge badge-danger">{{ $log->action }}</span>
                                @else
                                    <span class="badge badge-info">{{ $log->action }}</span>
                                @endif
                            </td>
                            <td>
                                @if($log->tenant)
                                    <span style="font-weight: 500;">{{ $log->tenant->name }}</span>
                                @else
                                    <span style="color: var(--text-secondary); font-style: italic;">Sistem</span>
                                @endif
                            </td>
                            <td>{{ $log->details }}</td>
                            <td>{{ $log->user ? $log->user->name : 'Sistem' }}</td>
                            <td>
                                <div><code>{{ $log->ip_address }}</code></div>
                                <div style="font-size: 11px; color: var(--text-secondary); max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="{{ $log->user_agent }}">
                                    {{ $log->user_agent }}
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" style="text-align: center; color: var(--text-secondary); padding: 32px;">Belum ada log audit terekam.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div style="margin-top: 24px;">
            {{ $logs->appends(request()->query())->links() }}
        </div>
    </div>
@endsection
