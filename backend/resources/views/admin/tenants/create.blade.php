@extends('admin.layouts.app')

@section('title', 'Pemesanan Lisensi & Pelanggan — Kasir Pro Admin')
@section('header_title', 'Pemesanan Lisensi & Data Pelanggan')

@section('styles')
<style>
    .order-container {
        max-width: 780px;
        margin: 0 auto;
    }
    .segment-header {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-bottom: 16px;
        padding-bottom: 8px;
        border-bottom: 2px solid var(--primary-container);
    }
    .segment-header .step-badge {
        width: 28px;
        height: 28px;
        border-radius: 50%;
        background-color: var(--primary);
        color: white;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 13px;
        font-weight: 700;
    }
    .segment-header h3 {
        font-size: 15px;
        font-weight: 600;
        color: var(--primary);
        margin: 0;
    }
    .customer-mode-toggle {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
        margin-bottom: 20px;
    }
    .mode-card {
        border: 2px solid var(--divider);
        border-radius: 12px;
        padding: 14px 16px;
        cursor: pointer;
        transition: all 0.2s ease;
        display: flex;
        align-items: center;
        gap: 12px;
        background: white;
    }
    .mode-card:hover {
        border-color: var(--primary);
        background: #F8FAFC;
    }
    .mode-card.active {
        border-color: var(--primary);
        background: var(--primary-container);
    }
    .mode-card input[type="radio"] {
        display: none;
    }
    .mode-icon {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        background: rgba(20, 70, 131, 0.1);
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--primary);
        flex-shrink: 0;
    }
    .mode-card.active .mode-icon {
        background: var(--primary);
        color: white;
    }
    .mode-info .title {
        font-weight: 600;
        font-size: 14px;
        color: var(--text-primary);
    }
    .mode-info .subtitle {
        font-size: 12px;
        color: var(--text-secondary);
        margin-top: 2px;
    }

    /* Expandable Form Segment */
    .expandable-segment {
        overflow: hidden;
        transition: max-height 0.35s ease, opacity 0.3s ease, margin 0.3s ease;
    }
    .expandable-segment.collapsed {
        max-height: 0;
        opacity: 0;
        margin-top: 0;
        margin-bottom: 0;
        pointer-events: none;
        visibility: hidden;
    }
    .expandable-segment.expanded {
        max-height: 2000px;
        opacity: 1;
        margin-top: 16px;
        margin-bottom: 24px;
        pointer-events: auto;
        visibility: visible;
    }

    .type-pill-group {
        display: inline-flex;
        background: var(--surface);
        padding: 4px;
        border-radius: 10px;
        border: 1px solid var(--divider);
        gap: 4px;
    }
    .type-pill {
        padding: 6px 16px;
        border-radius: 8px;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s ease;
        color: var(--text-secondary);
        border: none;
        background: transparent;
    }
    .type-pill.active {
        background: var(--primary);
        color: white;
        font-weight: 600;
    }

    .stepper-input {
        display: flex;
        align-items: center;
        max-width: 180px;
    }
    .stepper-btn {
        width: 42px;
        height: 42px;
        border: 1px solid var(--divider);
        background: var(--surface);
        font-size: 18px;
        font-weight: 600;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
    }
    .stepper-btn:hover {
        background: var(--primary-container);
        color: var(--primary);
    }
    .stepper-btn.minus { border-radius: 12px 0 0 12px; }
    .stepper-btn.plus { border-radius: 0 12px 12px 0; }
    .stepper-input input {
        border-radius: 0 !important;
        text-align: center;
        font-weight: 700;
        font-size: 16px;
        border-left: none;
        border-right: none;
    }

    .summary-card {
        background: #F8FAFC;
        border: 1.5px solid var(--primary-container);
        border-radius: 14px;
        padding: 18px;
        margin-top: 24px;
    }
    .summary-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 13px;
        color: var(--text-secondary);
        margin-bottom: 8px;
    }
    .summary-total {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-top: 1px dashed var(--divider);
        padding-top: 12px;
        margin-top: 12px;
    }
    .summary-total .label {
        font-size: 14px;
        font-weight: 600;
        color: var(--text-primary);
    }
    .summary-total .value {
        font-size: 20px;
        font-weight: 700;
        color: var(--primary);
    }
</style>
@endsection

@section('content')
<div class="order-container">
    <div class="card">
        <div class="card-header">
            <div>
                <h2 class="card-title">Form Pemesanan Lisensi & Pelanggan</h2>
                <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">
                    Daftarkan lisensi perangkat baru untuk pelanggan lama (repeat order) atau pelanggan baru.
                </p>
            </div>
        </div>

        <form action="{{ route('admin.tenants.store') }}" method="POST" id="licenseOrderForm">
            @csrf

            <!-- STEP 1: PILIH ATAU DAFTARKAN CUSTOMER -->
            <div class="segment-header">
                <div class="step-badge">1</div>
                <h3>Pilih Data Pelanggan</h3>
            </div>

            <div class="customer-mode-toggle">
                <label class="mode-card {{ old('customer_mode', 'existing') === 'existing' ? 'active' : '' }}" id="card_existing" onclick="setCustomerMode('existing')">
                    <input type="radio" name="customer_mode" id="mode_existing" value="existing" {{ old('customer_mode', 'existing') === 'existing' ? 'checked' : '' }}>
                    <div class="mode-icon">
                        <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                        </svg>
                    </div>
                    <div class="mode-info">
                        <div class="title">Pelanggan Terdaftar</div>
                        <div class="subtitle">Pilih pelanggan existing untuk penambahan lisensi</div>
                    </div>
                </label>

                <label class="mode-card {{ old('customer_mode') === 'new' ? 'active' : '' }}" id="card_new" onclick="setCustomerMode('new')">
                    <input type="radio" name="customer_mode" id="mode_new" value="new" {{ old('customer_mode') === 'new' ? 'checked' : '' }}>
                    <div class="mode-icon">
                        <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                        </svg>
                    </div>
                    <div class="mode-info">
                        <div class="title">+ Pelanggan Baru</div>
                        <div class="subtitle">Buat data pelanggan baru beserta akun login</div>
                    </div>
                </label>
            </div>

            <!-- Bagian Dropdown Pelanggan Existing -->
            <div id="existing_customer_container" style="margin-bottom: 20px;">
                <div class="form-group" style="margin-bottom: 8px;">
                    <label class="form-label" for="customer_search_input">Cari & Pilih Pelanggan *</label>
                    <div style="position: relative;">
                        <input type="text" id="customer_search_input" class="form-control" placeholder="Ketik nama bisnis, pemilik, email, atau telepon..." oninput="filterCustomerOptions()" autocomplete="off">
                        <div id="customer_dropdown_list" style="display: none; position: absolute; top: 100%; left: 0; right: 0; max-height: 240px; overflow-y: auto; background: white; border: 1px solid var(--divider); border-radius: 10px; box-shadow: 0 4px 16px rgba(0,0,0,0.1); z-index: 50; margin-top: 4px;">
                            @foreach ($customers as $c)
                                <div class="customer-opt-item" 
                                    data-id="{{ $c->id }}"
                                    data-name="{{ $c->name }}"
                                    data-owner="{{ $c->owner_name }}"
                                    data-email="{{ $c->email }}"
                                    data-phone="{{ $c->phone }}"
                                    data-type="{{ $c->customer_type_label }}"
                                    onclick="selectCustomer('{{ $c->id }}', '{{ addslashes($c->name) }}', '{{ addslashes($c->owner_name) }}', '{{ $c->email }}', '{{ $c->customer_type_label }}')"
                                    style="padding: 10px 16px; border-bottom: 1px solid var(--divider); cursor: pointer; transition: background 0.15s ease;">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <div style="font-weight: 600; font-size: 13px; color: var(--text-primary);">{{ $c->name }}</div>
                                        <span class="badge {{ $c->customer_type === 'company' ? 'badge-info' : 'badge-warning' }}" style="font-size: 10px;">{{ $c->customer_type_label }}</span>
                                    </div>
                                    <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">
                                        Owner: {{ $c->owner_name }} &bull; {{ $c->email }} &bull; {{ $c->phone ?? '-' }}
                                    </div>
                                </div>
                            @endforeach
                            <div id="customer_empty_state" style="display: none; padding: 16px; text-align: center;">
                                <div style="font-size: 13px; color: var(--text-secondary); margin-bottom: 8px;">Pelanggan tidak ditemukan.</div>
                                <button type="button" class="btn btn-xs btn-primary" onclick="setCustomerMode('new')">+ Daftarkan Sebagai Pelanggan Baru</button>
                            </div>
                        </div>
                    </div>
                    <input type="hidden" name="customer_id" id="customer_id" value="{{ old('customer_id') }}">
                    @error('customer_id') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div id="selected_customer_preview" style="display: none; padding: 12px 16px; background: var(--surface); border: 1px solid var(--divider); border-radius: 10px; margin-top: 8px; justify-content: space-between; align-items: center;">
                    <div>
                        <div style="font-weight: 600; font-size: 14px; color: var(--primary);" id="preview_cust_name"></div>
                        <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;" id="preview_cust_detail"></div>
                    </div>
                    <button type="button" class="btn btn-xs btn-outline" onclick="clearSelectedCustomer()">Ganti</button>
                </div>
            </div>

            <!-- Bagian Expandable Form Pelanggan Baru -->
            <div id="new_customer_segment" class="expandable-segment {{ old('customer_mode') === 'new' ? 'expanded' : 'collapsed' }}">
                <div style="background: var(--surface); padding: 20px; border-radius: 14px; border: 1px solid var(--divider);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
                        <span style="font-size: 13px; font-weight: 600; color: var(--text-primary);">Tipe Pelanggan *</span>
                        <div class="type-pill-group">
                            <button type="button" class="type-pill {{ old('customer_type', 'individual') === 'individual' ? 'active' : '' }}" id="pill_individual" onclick="setCustomerType('individual')">Pribadi / Perorangan</button>
                            <button type="button" class="type-pill {{ old('customer_type') === 'company' ? 'active' : '' }}" id="pill_company" onclick="setCustomerType('company')">Perusahaan / Badan Usaha</button>
                        </div>
                        <input type="hidden" name="customer_type" id="customer_type" value="{{ old('customer_type', 'individual') }}">
                    </div>

                    <div class="grid grid-2">
                        <div class="form-group">
                            <label class="form-label" for="name" id="label_business_name">Nama Bisnis / Perusahaan *</label>
                            <input class="form-control cust-field" type="text" id="name" name="name" value="{{ old('name') }}" placeholder="Contoh: CV Maju Bersama">
                            @error('name') <div class="form-error">{{ $message }}</div> @enderror
                        </div>

                        <div class="form-group">
                            <label class="form-label" for="owner_name">Nama Pemilik / PIC *</label>
                            <input class="form-control cust-field" type="text" id="owner_name" name="owner_name" value="{{ old('owner_name') }}" placeholder="Contoh: Budi Santoso">
                            @error('owner_name') <div class="form-error">{{ $message }}</div> @enderror
                        </div>
                    </div>

                    <div class="form-group" id="tax_number_wrapper" style="display: {{ old('customer_type') === 'company' ? 'block' : 'none' }};">
                        <label class="form-label" for="tax_number">NPWP Perusahaan (Nomor Pokok Wajib Pajak)</label>
                        <input class="form-control cust-field" type="text" id="tax_number" name="tax_number" value="{{ old('tax_number') }}" placeholder="Contoh: 01.234.567.8-901.000">
                        @error('tax_number') <div class="form-error">{{ $message }}</div> @enderror
                    </div>

                    <div class="grid grid-2">
                        <div class="form-group">
                            <label class="form-label" for="email">Email Kredensial Login *</label>
                            <input class="form-control cust-field" type="email" id="email" name="email" value="{{ old('email') }}" placeholder="Contoh: owner@majubersama.com">
                            @error('email') <div class="form-error">{{ $message }}</div> @enderror
                        </div>

                        <div class="form-group">
                            <label class="form-label" for="password">Password Login *</label>
                            <div style="position: relative;">
                                <input class="form-control cust-field" type="password" id="password" name="password" placeholder="Minimal 6 karakter" style="padding-right: 44px;">
                                <button type="button" onclick="togglePasswordVisibility()" style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; padding: 4px; color: var(--text-secondary);" title="Tampilkan / Sembunyikan">
                                    <svg id="eye_icon" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                    </svg>
                                </button>
                            </div>
                            @error('password') <div class="form-error">{{ $message }}</div> @enderror
                        </div>
                    </div>

                    <div class="grid grid-2">
                        <div class="form-group">
                            <label class="form-label" for="phone">No WhatsApp / Telepon (Hanya Angka)</label>
                            <input class="form-control cust-field" type="text" id="phone" name="phone" value="{{ old('phone') }}" placeholder="Contoh: 08123456789" oninput="this.value = this.value.replace(/[^0-9]/g, '')">
                            @error('phone') <div class="form-error">{{ $message }}</div> @enderror
                        </div>

                        <div class="form-group">
                            <label class="form-label" for="store_name">Nama Toko / Outlet Utama</label>
                            <input class="form-control cust-field" type="text" id="store_name" name="store_name" value="{{ old('store_name') }}" placeholder="Contoh: Outlet Sudirman">
                            @error('store_name') <div class="form-error">{{ $message }}</div> @enderror
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label" for="store_address">Alamat Toko / Kantor</label>
                        <input class="form-control cust-field" type="text" id="store_address" name="store_address" value="{{ old('store_address') }}" placeholder="Contoh: Jl. Sudirman No. 45">
                        @error('store_address') <div class="form-error">{{ $message }}</div> @enderror
                    </div>
                </div>
            </div>

            <!-- STEP 2: PAKET & JUMLAH LISENSI -->
            <div class="segment-header" style="margin-top: 24px;">
                <div class="step-badge">2</div>
                <h3>Konfigurasi Paket & Jumlah Lisensi</h3>
            </div>

            <div class="grid grid-2">
                <div class="form-group">
                    <label class="form-label" for="package_id">Pilih Paket SaaS *</label>
                    <select class="form-control" id="package_id" name="package_id" required onchange="calculateOrderSummary()">
                        <option value="">-- Pilih Paket --</option>
                        @foreach ($packages as $pkg)
                            <option value="{{ $pkg->id }}" 
                                data-name="{{ $pkg->name }}"
                                data-price="{{ $pkg->price }}"
                                data-price-formatted="{{ number_format($pkg->price, 0, ',', '.') }}"
                                data-validity="{{ $pkg->validity_type }}"
                                data-days="{{ $pkg->default_duration_days }}"
                                {{ old('package_id') == $pkg->id ? 'selected' : '' }}>
                                {{ $pkg->name }} — Rp {{ number_format($pkg->price, 0, ',', '.') }}
                            </option>
                        @endforeach
                    </select>
                    @error('package_id') <div class="form-error">{{ $message }}</div> @enderror
                </div>

                <div class="form-group">
                    <label class="form-label" for="quantity">Jumlah Lisensi Device (Unit) *</label>
                    <div class="stepper-input">
                        <button type="button" class="stepper-btn minus" onclick="adjustQuantity(-1)">-</button>
                        <input class="form-control" type="number" id="quantity" name="quantity" min="1" max="100" value="{{ old('quantity', 1) }}" required oninput="calculateOrderSummary()">
                        <button type="button" class="stepper-btn plus" onclick="adjustQuantity(1)">+</button>
                    </div>
                    <span style="font-size: 11px; color: var(--text-secondary); margin-top: 4px; display: block;">1 lisensi = 1 perangkat kasir POS</span>
                    @error('quantity') <div class="form-error">{{ $message }}</div> @enderror
                </div>
            </div>

            <div class="form-group">
                <label class="form-label" for="client_note">Catatan Lisensi / Referensi Order (Opsional)</label>
                <input class="form-control" type="text" id="client_note" name="client_note" value="{{ old('client_note') }}" placeholder="Contoh: Lisensi Kasir Cabang 1 & Cabang 2">
                @error('client_note') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <!-- STEP 3: STATUS PEMBAYARAN & RINGKASAN HARGA -->
            <div class="segment-header" style="margin-top: 24px;">
                <div class="step-badge">3</div>
                <h3>Pembayaran & Ringkasan</h3>
            </div>

            <div class="form-group">
                <label class="form-label">Status Pembayaran Invoice *</label>
                <div style="display: flex; gap: 16px; flex-wrap: wrap;">
                    <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 14px;">
                        <input type="radio" name="payment_status" value="paid" {{ old('payment_status', 'paid') === 'paid' ? 'checked' : '' }}>
                        <span style="font-weight: 600; color: var(--success);">Langsung Lunas (Terbitkan Lisensi Seketika)</span>
                    </label>
                    <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 14px;">
                        <input type="radio" name="payment_status" value="unpaid" {{ old('payment_status') === 'unpaid' ? 'checked' : '' }}>
                        <span style="font-weight: 500; color: var(--warning);">Terbitkan Invoice (Menunggu Pembayaran)</span>
                    </label>
                </div>
                @error('payment_status') <div class="form-error">{{ $message }}</div> @enderror
            </div>

            <!-- Order Summary Box -->
            <div class="summary-card" id="order_calculation_summary">
                <div style="font-size: 13px; font-weight: 700; color: var(--primary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;">
                    Ringkasan Pemesanan
                </div>
                <div class="summary-row">
                    <span id="summary_pkg_name">Paket SaaS: Belum dipilih</span>
                    <span id="summary_pkg_price">Rp 0 / lisensi</span>
                </div>
                <div class="summary-row">
                    <span>Jumlah Lisensi:</span>
                    <span id="summary_qty">1 Unit</span>
                </div>
                <div class="summary-total">
                    <span class="label">Total Tagihan (Invoice):</span>
                    <span class="value" id="summary_grand_total">Rp 0</span>
                </div>
            </div>

            <div style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 32px;">
                <a href="{{ route('admin.tenants.index') }}" class="btn btn-outline">Batal</a>
                <button type="submit" class="btn btn-primary" id="btn_submit_order">
                    <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Simpan & Proses Lisensi</span>
                </button>
            </div>
        </form>
    </div>
</div>
@endsection

@section('scripts')
<script>
    let currentMode = '{{ old("customer_mode", "existing") }}';

    function setCustomerMode(mode) {
        currentMode = mode;
        const cardExisting = document.getElementById('card_existing');
        const cardNew = document.getElementById('card_new');
        const radioExisting = document.getElementById('mode_existing');
        const radioNew = document.getElementById('mode_new');
        const existingContainer = document.getElementById('existing_customer_container');
        const newSegment = document.getElementById('new_customer_segment');
        const custFields = document.querySelectorAll('.cust-field');

        if (mode === 'new') {
            cardExisting.classList.remove('active');
            cardNew.classList.add('active');
            radioNew.checked = true;
            existingContainer.style.display = 'none';
            newSegment.classList.remove('collapsed');
            newSegment.classList.add('expanded');
            
            custFields.forEach(f => f.removeAttribute('disabled'));
            document.getElementById('name').setAttribute('required', 'required');
            document.getElementById('owner_name').setAttribute('required', 'required');
            document.getElementById('email').setAttribute('required', 'required');
            document.getElementById('password').setAttribute('required', 'required');
            document.getElementById('customer_id').value = '';
        } else {
            cardNew.classList.remove('active');
            cardExisting.classList.add('active');
            radioExisting.checked = true;
            existingContainer.style.display = 'block';
            newSegment.classList.remove('expanded');
            newSegment.classList.add('collapsed');
            
            custFields.forEach(f => {
                f.setAttribute('disabled', 'disabled');
                f.removeAttribute('required');
            });
        }
    }

    function setCustomerType(type) {
        document.getElementById('customer_type').value = type;
        const pillInd = document.getElementById('pill_individual');
        const pillComp = document.getElementById('pill_company');
        const taxWrapper = document.getElementById('tax_number_wrapper');
        const labelName = document.getElementById('label_business_name');

        if (type === 'company') {
            pillComp.classList.add('active');
            pillInd.classList.remove('active');
            taxWrapper.style.display = 'block';
            labelName.textContent = 'Nama Perusahaan / Instansi *';
        } else {
            pillInd.classList.add('active');
            pillComp.classList.remove('active');
            taxWrapper.style.display = 'none';
            labelName.textContent = 'Nama Usaha / Pelanggan *';
        }
    }

    function filterCustomerOptions() {
        const input = document.getElementById('customer_search_input');
        const filter = input.value.toLowerCase().trim();
        const list = document.getElementById('customer_dropdown_list');
        const items = list.getElementsByClassName('customer-opt-item');
        const emptyState = document.getElementById('customer_empty_state');
        
        list.style.display = 'block';
        let matchCount = 0;

        for (let i = 0; i < items.length; i++) {
            const name = items[i].getAttribute('data-name').toLowerCase();
            const owner = items[i].getAttribute('data-owner').toLowerCase();
            const email = items[i].getAttribute('data-email').toLowerCase();
            const phone = (items[i].getAttribute('data-phone') || '').toLowerCase();

            if (name.includes(filter) || owner.includes(filter) || email.includes(filter) || phone.includes(filter)) {
                items[i].style.display = 'block';
                matchCount++;
            } else {
                items[i].style.display = 'none';
            }
        }

        if (matchCount === 0) {
            emptyState.style.display = 'block';
        } else {
            emptyState.style.display = 'none';
        }
    }

    function selectCustomer(id, name, owner, email, type) {
        document.getElementById('customer_id').value = id;
        document.getElementById('customer_search_input').value = '';
        document.getElementById('customer_dropdown_list').style.display = 'none';
        
        const preview = document.getElementById('selected_customer_preview');
        document.getElementById('preview_cust_name').textContent = name + ' (' + type + ')';
        document.getElementById('preview_cust_detail').textContent = 'Owner: ' + owner + ' | Email: ' + email;
        preview.style.display = 'flex';
    }

    function clearSelectedCustomer() {
        document.getElementById('customer_id').value = '';
        document.getElementById('selected_customer_preview').style.display = 'none';
        document.getElementById('customer_search_input').focus();
    }

    document.addEventListener('click', function(e) {
        const list = document.getElementById('customer_dropdown_list');
        const searchInput = document.getElementById('customer_search_input');
        if (list && searchInput && !list.contains(e.target) && e.target !== searchInput) {
            list.style.display = 'none';
        }
    });

    document.getElementById('customer_search_input').addEventListener('focus', function() {
        if (this.value.trim().length > 0 || {{ count($customers) }} > 0) {
            filterCustomerOptions();
        }
    });

    function adjustQuantity(delta) {
        const qtyInput = document.getElementById('quantity');
        let current = parseInt(qtyInput.value) || 1;
        current = Math.max(1, Math.min(100, current + delta));
        qtyInput.value = current;
        calculateOrderSummary();
    }

    function calculateOrderSummary() {
        const packageSelect = document.getElementById('package_id');
        const qtyInput = document.getElementById('quantity');
        const selectedOpt = packageSelect.options[packageSelect.selectedIndex];

        const summaryPkgName = document.getElementById('summary_pkg_name');
        const summaryPkgPrice = document.getElementById('summary_pkg_price');
        const summaryQty = document.getElementById('summary_qty');
        const summaryTotal = document.getElementById('summary_grand_total');

        const quantity = Math.max(1, parseInt(qtyInput.value) || 1);
        summaryQty.textContent = quantity + ' Unit';

        if (!selectedOpt || !selectedOpt.value) {
            summaryPkgName.textContent = 'Paket SaaS: Belum dipilih';
            summaryPkgPrice.textContent = 'Rp 0 / lisensi';
            summaryTotal.textContent = 'Rp 0';
            return;
        }

        const price = parseInt(selectedOpt.getAttribute('data-price')) || 0;
        const formattedPrice = selectedOpt.getAttribute('data-price-formatted') || '0';
        const pkgName = selectedOpt.getAttribute('data-name') || selectedOpt.text;
        const total = price * quantity;

        summaryPkgName.textContent = 'Paket SaaS: ' + pkgName;
        summaryPkgPrice.textContent = 'Rp ' + formattedPrice + ' / lisensi';
        summaryTotal.textContent = 'Rp ' + new Intl.NumberFormat('id-ID').format(total);
    }

    function togglePasswordVisibility() {
        const input = document.getElementById('password');
        const icon = document.getElementById('eye_icon');
        if (input.type === 'password') {
            input.type = 'text';
            icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858-5.908a10.018 10.018 0 014.122-.963c4.478 0 8.268 2.943 9.542 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21M3 3l18 18" />`;
        } else {
            input.type = 'password';
            icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />`;
        }
    }

    document.addEventListener('DOMContentLoaded', function() {
        setCustomerMode('{{ old("customer_mode", "existing") }}');
        
        @if(old('customer_id'))
            @php
                $oldCust = $customers->firstWhere('id', old('customer_id'));
            @endphp
            @if($oldCust)
                selectCustomer('{{ $oldCust->id }}', '{{ addslashes($oldCust->name) }}', '{{ addslashes($oldCust->owner_name) }}', '{{ $oldCust->email }}', '{{ $oldCust->customer_type_label }}');
            @endif
        @endif

        calculateOrderSummary();
    });
</script>
@endsection
