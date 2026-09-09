@extends('admin.layouts.app')
@section('title', 'Tenant ' . $tenant->name . ' - Kasir Pro Admin')
@section('header_title', $tenant->name)

@section('content')
<div class="grid grid-2">
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Informasi Tenant</h3>
            <span class="badge {{ $tenant->status->badgeClass() }}">{{ $tenant->status->label() }}</span>
        </div>
        <div class="detail-grid">
            <div class="detail-label">Nama</div><div class="detail-value">{{ $tenant->name }}</div>
            <div class="detail-label">Pemilik</div><div class="detail-value">{{ $tenant->owner_name }}</div>
            <div class="detail-label">Email</div><div class="detail-value">{{ $tenant->email }}</div>
            <div class="detail-label">Telepon</div><div class="detail-value">{{ $tenant->phone ?? '-' }}</div>
            <div class="detail-label">Toko</div><div class="detail-value">{{ $tenant->store_name ?? '-' }}</div>
            <div class="detail-label">Alamat</div><div class="detail-value">{{ $tenant->store_address ?? '-' }}</div>
            <div class="detail-label">Bergabung</div><div class="detail-value">{{ $tenant->created_at->format('d F Y') }}</div>
        </div>
        <div class="flex gap-3 mt-4 flex-wrap">
            <a href="{{ route('admin.tenants.edit', $tenant) }}" class="btn btn-outline btn-sm">Edit</a>
            @can('tenants.suspend')
                @if ($tenant->status->value === 'active')
                    <form method="POST" action="{{ route('admin.tenants.suspend', $tenant) }}" onsubmit="return confirm('Tangguhkan tenant ini?')">@csrf<button class="btn btn-warning btn-sm">Tangguhkan</button></form>
                @elseif ($tenant->status->value === 'suspended')
                    <form method="POST" action="{{ route('admin.tenants.reactivate', $tenant) }}" onsubmit="return confirm('Aktifkan kembali tenant ini?')">@csrf<button class="btn btn-success btn-sm">Aktifkan</button></form>
                @endif
            @endcan
            @can('tenants.delete')
                <form method="POST" action="{{ route('admin.tenants.destroy', $tenant) }}" onsubmit="return confirm('Hapus tenant ini? Data akan dihapus.')">@csrf @method('DELETE')<button class="btn btn-danger btn-sm">Hapus</button></form>
            @endcan
        </div>
    </div>

    @can('tenants.generate_license')
    <div class="card">
        <div class="card-header"><h3 class="card-title">Generator Lisensi (Perbarui Expired & Terbitkan Token)</h3></div>
        @php
            $activeSub = $tenant->subscriptions->where('status', \App\Enums\SubscriptionStatus::ACTIVE)->first();
            $defaultDate = $activeSub ? $activeSub->expiry_date->format('Y-m-d') : now()->addYear()->format('Y-m-d');
        @endphp
        <form action="{{ route('admin.tenants.generate-license', $tenant) }}" method="POST" style="margin-top: 12px;">
            @csrf
            <div class="form-group" style="margin-bottom: 12px;">
                <label class="form-label" for="expiry_date">Tanggal Kedaluwarsa Lisensi Klien</label>
                <input class="form-control" type="date" id="expiry_date" name="expiry_date" value="{{ $defaultDate }}" required>
            </div>
            <div class="form-group" style="margin-bottom: 12px;">
                <label class="form-label" for="client_note">Catatan Tambahan (Opsional)</label>
                <input class="form-control" type="text" id="client_note" name="client_note" placeholder="Misal: Perpanjangan Paket 1 Tahun">
            </div>
            <button type="submit" class="btn btn-primary btn-sm" style="width: 100%;">Perbarui Tanggal & Generate Token Baru</button>
        </form>
    </div>
    @endcan
</div>

@if ($tenant->licenseTokens->count() > 0)
<div class="card">
    <div class="card-header"><h3 class="card-title">Token Lisensi ({{ $tenant->licenseTokens->count() }})</h3></div>
    <div class="table-responsive">
        <table class="table">
            <thead><tr><th>Token</th><th>Status</th><th>Perangkat</th><th>Aksi</th></tr></thead>
            <tbody>
                @foreach ($tenant->licenseTokens as $token)
                <tr>
                    <td><span class="token-display">{{ $token->token_key }}</span></td>
                    <td><span class="badge {{ $token->status->badgeClass() }}">{{ $token->status->label() }}</span></td>
                    <td>{{ $token->device?->display_name ?? '-' }}</td>
                    <td><a href="{{ route('admin.tokens.show', $token) }}" class="btn btn-outline btn-xs">Detail</a></td>
                </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
@endif

<a href="{{ route('admin.tenants.index') }}" class="btn btn-outline btn-sm">← Kembali</a>
@endsection
