<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CustomerViewUiTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Package $package;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        $this->admin = User::create([
            'name' => 'Admin SaaS',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('Password'),
            'is_admin' => true,
        ]);

        $this->package = Package::create([
            'name' => 'Pro Plan',
            'slug' => 'pro-plan',
            'price' => 350000,
            'validity_type' => 'duration',
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);
    }

    public function test_create_order_view_renders_all_required_ui_elements(): void
    {
        $existingCustomer = Tenant::create([
            'name' => 'PT Maju Jaya',
            'customer_type' => 'company',
            'tax_number' => '01.234.567.8-999.000',
            'owner_name' => 'Hendra Setiawan',
            'email' => 'hendra@majujaya.com',
            'phone' => '08123456789',
            'status' => 'active',
        ]);

        $response = $this->actingAs($this->admin)->get(route('admin.tenants.create'));

        $response->assertStatus(200);

        // 1. Assert Header and Title
        $response->assertSee('Form Pemesanan Lisensi & Pelanggan', false);
        $response->assertSee('Pilih Data Pelanggan', false);

        // 2. Assert Customer Mode Toggle & Search container
        $response->assertSee('Pelanggan Terdaftar');
        $response->assertSee('+ Pelanggan Baru');
        $response->assertSee('id="customer_search_input"', false);
        $response->assertSee('id="customer_dropdown_list"', false);
        $response->assertSee('PT Maju Jaya');
        $response->assertSee('Hendra Setiawan');
        $response->assertSee('hendra@majujaya.com');
        $response->assertSee('+ Daftarkan Sebagai Pelanggan Baru');

        // 3. Assert Expandable New Customer Form Segment
        $response->assertSee('id="new_customer_segment"', false);
        $response->assertSee('Pribadi / Perorangan');
        $response->assertSee('Perusahaan / Badan Usaha');
        $response->assertSee('id="pill_individual"', false);
        $response->assertSee('id="pill_company"', false);
        $response->assertSee('id="tax_number_wrapper"', false);
        $response->assertSee('id="name"', false);
        $response->assertSee('id="owner_name"', false);
        $response->assertSee('id="email"', false);
        $response->assertSee('id="password"', false);
        $response->assertSee('id="eye_icon"', false);
        $response->assertSee('id="phone"', false);
        $response->assertSee('id="store_name"', false);
        $response->assertSee('id="store_address"', false);

        // 4. Assert License Configuration Segment
        $response->assertSee('Konfigurasi Paket & Jumlah Lisensi', false);
        $response->assertSee('id="package_id"', false);
        $response->assertSee('Pro Plan');
        $response->assertSee('id="quantity"', false);
        $response->assertSee('min="1"', false);
        $response->assertSee('max="100"', false);
        $response->assertSee('class="stepper-btn minus"', false);
        $response->assertSee('class="stepper-btn plus"', false);
        $response->assertSee('id="client_note"', false);

        // 5. Assert Payment & Order Live Summary Elements
        $response->assertSee('Langsung Lunas (Terbitkan Lisensi Seketika)');
        $response->assertSee('Terbitkan Invoice (Menunggu Pembayaran)');
        $response->assertSee('id="order_calculation_summary"', false);
        $response->assertSee('id="summary_pkg_name"', false);
        $response->assertSee('id="summary_pkg_price"', false);
        $response->assertSee('id="summary_qty"', false);
        $response->assertSee('id="summary_grand_total"', false);
        $response->assertSee('id="btn_submit_order"', false);
    }

    public function test_index_view_displays_customer_nomenclature_badges_and_counters(): void
    {
        $tenantCompany = Tenant::create([
            'name' => 'PT Nusantara Sejahtera',
            'customer_type' => 'company',
            'tax_number' => '09.876.543.2-111.000',
            'owner_name' => 'Bambang Sudiro',
            'email' => 'bambang@nusantara.com',
            'phone' => '08111222333',
            'status' => 'active',
        ]);

        $tenantIndiv = Tenant::create([
            'name' => 'Warung Kopi Mas Budi',
            'customer_type' => 'individual',
            'owner_name' => 'Budi Prasetyo',
            'email' => 'budi@warkopbudi.com',
            'phone' => '08222333444',
            'status' => 'active',
        ]);

        $response = $this->actingAs($this->admin)->get(route('admin.tenants.index'));

        $response->assertStatus(200);

        // Assert Sidebar and page headers
        $response->assertSee('Data Pelanggan');
        $response->assertSee('Daftar Pelanggan & Lisensi', false);
        $response->assertSee('+ Pesan Lisensi / Pelanggan Baru', false);

        // Assert Customer records and badges
        $response->assertSee('PT Nusantara Sejahtera');
        $response->assertSee('NPWP: 09.876.543.2-111.000');
        $response->assertSee('Perusahaan');
        $response->assertSee('Warung Kopi Mas Budi');
        $response->assertSee('Pribadi');
        $response->assertSee('Perangkat');
    }

    public function test_show_view_displays_customer_profile_and_tokens_table(): void
    {
        $tenant = Tenant::create([
            'name' => 'CV Sumber Makmur',
            'customer_type' => 'company',
            'tax_number' => '12.345.678.9-000.000',
            'owner_name' => 'Dewi Lestari',
            'email' => 'dewi@makmur.com',
            'phone' => '08555666777',
            'city' => 'Surabaya',
            'postal_code' => '60111',
            'status' => 'active',
        ]);

        $response = $this->actingAs($this->admin)->get(route('admin.tenants.show', $tenant));

        $response->assertStatus(200);
        $response->assertSee('Informasi Pelanggan', false);
        $response->assertSee('CV Sumber Makmur', false);
        $response->assertSee('Perusahaan', false);
        $response->assertSee('12.345.678.9-000.000', false);
        $response->assertSee('Dewi Lestari', false);
        $response->assertSee('dewi@makmur.com', false);
        $response->assertSee('Surabaya', false);
        $response->assertSee('+ Tambah Lisensi', false);
        $response->assertSee('Riwayat Tagihan & Pembelian Lisensi', false);
    }
}
