@extends('admin.layouts.app')
@section('title', 'Buat Invoice - POS SaaS Admin')
@section('header_title', 'Buat Invoice Baru')

@section('content')
<div class="card">
    <form method="POST" action="{{ route('admin.invoices.store') }}" id="invoiceForm">
        @csrf

        <div class="form-group">
            <label class="form-label">Tenant *</label>
            <select name="tenant_id" class="form-control" required>
                <option value="">Pilih Tenant</option>
                @foreach ($tenants as $tenant)
                    <option value="{{ $tenant->id }}" {{ old('tenant_id') === $tenant->id ? 'selected' : '' }}>
                        {{ $tenant->name }} - {{ $tenant->email }}
                    </option>
                @endforeach
            </select>
            @error('tenant_id') <div class="form-error">{{ $message }}</div> @enderror
        </div>

        <div class="card-title mb-4" style="margin-top: 24px;">Item Invoice</div>
        <div id="invoice-items">
            <div class="item-row" style="display: grid; grid-template-columns: 2fr 2fr 1fr 1fr auto; gap: 12px; margin-bottom: 16px; align-items: end;">
                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Paket *</label>
                    <select name="items[0][package_id]" class="form-control package-select" required>
                        <option value="">Pilih Paket</option>
                        @foreach ($packages as $pkg)
                            <option value="{{ $pkg->id }}" data-price="{{ $pkg->price }}" data-duration="{{ $pkg->default_duration_days }}">
                                {{ $pkg->name }} - Rp {{ number_format($pkg->price, 0, ',', '.') }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Catatan Mesin Klien</label>
                    <input type="text" name="items[0][client_note]" class="form-control" placeholder="Misal: Tablet Mesin Kasir Depan Utama">
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Qty *</label>
                    <input type="number" name="items[0][quantity]" class="form-control" value="1" min="1" max="20" required>
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Durasi (hari)</label>
                    <input type="number" name="items[0][duration_days]" class="form-control duration-input" min="1" placeholder="Default paket">
                </div>
                <div style="padding-bottom: 4px;"></div>
            </div>
        </div>

        <button type="button" id="addItem" class="btn btn-outline btn-sm" style="margin-bottom: 24px;">+ Tambah Item</button>

        <div class="form-group">
            <label class="form-label">Catatan Invoice</label>
            <textarea name="notes" class="form-control" rows="3" placeholder="Catatan untuk invoice (opsional)">{{ old('notes') }}</textarea>
        </div>

        @if ($errors->any())
            <div class="alert alert-danger">
                <ul style="margin: 0; padding-left: 20px;">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <div style="display: flex; gap: 12px;">
            <button type="submit" class="btn btn-primary">Buat Invoice</button>
            <a href="{{ route('admin.invoices.index') }}" class="btn btn-outline">Batal</a>
        </div>
    </form>
</div>

@section('scripts')
<script>
let itemIndex = 1;
document.getElementById('addItem').addEventListener('click', function() {
    const container = document.getElementById('invoice-items');
    const packagesOptions = document.querySelector('.package-select').innerHTML;
    const row = document.createElement('div');
    row.className = 'item-row';
    row.style.cssText = 'display: grid; grid-template-columns: 2fr 2fr 1fr 1fr auto; gap: 12px; margin-bottom: 16px; align-items: end;';
    row.innerHTML = `
        <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label">Paket *</label>
            <select name="items[${itemIndex}][package_id]" class="form-control package-select" required>${packagesOptions}</select>
        </div>
        <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label">Catatan Mesin Klien</label>
            <input type="text" name="items[${itemIndex}][client_note]" class="form-control" placeholder="Misal: Tablet Tambahan Antrean Belakang">
        </div>
        <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label">Qty *</label>
            <input type="number" name="items[${itemIndex}][quantity]" class="form-control" value="1" min="1" max="20" required>
        </div>
        <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label">Durasi (hari)</label>
            <input type="number" name="items[${itemIndex}][duration_days]" class="form-control duration-input" min="1" placeholder="Default paket">
        </div>
        <button type="button" class="btn btn-danger btn-xs remove-item" style="height: fit-content;">Hapus</button>
    `;
    container.appendChild(row);
    row.querySelector('.remove-item').addEventListener('click', function() { row.remove(); });
    itemIndex++;
});
</script>
@endsection
@endsection
