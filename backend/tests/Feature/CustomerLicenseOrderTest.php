<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TenantStatus;
use App\Enums\TokenStatus;
use App\Models\Invoice;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use App\Services\LicenseService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CustomerLicenseOrderTest extends TestCase
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

    public function test_new_individual_customer_order_with_bulk_licenses(): void
    {
        $this->actingAs($this->admin);

        $response = $this->post(route('admin.tenants.store'), [
            'customer_mode' => 'new',
            'customer_type' => 'individual',
            'name' => 'Kedai Kopi Bahagia',
            'owner_name' => 'Ahmad Bahagia',
            'email' => 'ahmad@kopibahagia.com',
            'password' => 'secret123',
            'phone' => '081234567890',
            'store_name' => 'Kedai Bahagia Pusat',
            'store_address' => 'Jl. Merdeka No. 10',
            'city' => 'Bandung',
            'postal_code' => '40115',
            'package_id' => $this->package->id,
            'quantity' => 3,
            'payment_status' => 'paid',
            'client_note' => 'Lisensi Kasir Kasir 1, 2, 3',
        ]);

        $response->assertSessionHasNoErrors();
        $response->assertRedirect();

        // 1. Assert Tenant
        $tenant = Tenant::where('email', 'ahmad@kopibahagia.com')->first();
        $this->assertNotNull($tenant);
        $this->assertEquals('individual', $tenant->customer_type);
        $this->assertEquals('Pribadi', $tenant->customer_type_label);
        $this->assertEquals('Bandung', $tenant->city);

        // 2. Assert User
        $user = User::where('email', 'ahmad@kopibahagia.com')->first();
        $this->assertNotNull($user);
        $this->assertEquals($tenant->id, $user->tenant_id);
        $this->assertTrue(Hash::check('secret123', $user->password));

        // 3. Assert Invoice
        $invoice = Invoice::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($invoice);
        $this->assertEquals(InvoiceStatus::PAID, $invoice->status);
        $this->assertEquals(350000 * 3, $invoice->total_amount);

        // 4. Assert 3 License Tokens generated
        $tokens = LicenseToken::where('tenant_id', $tenant->id)->get();
        $this->assertCount(3, $tokens);
        foreach ($tokens as $t) {
            $this->assertEquals(TokenStatus::AVAILABLE, $t->status);
            $this->assertStringContainsString('PRO', $t->token_key);
        }
    }

    public function test_new_company_customer_saves_tax_number(): void
    {
        $this->actingAs($this->admin);

        $response = $this->post(route('admin.tenants.store'), [
            'customer_mode' => 'new',
            'customer_type' => 'company',
            'tax_number' => '01.234.567.8-999.000',
            'name' => 'PT Retail Sejahtera Abadi',
            'owner_name' => 'Ir. Hartono',
            'email' => 'hartono@retailsejahtera.com',
            'password' => 'corporatePass123',
            'phone' => '082198765432',
            'package_id' => $this->package->id,
            'quantity' => 2,
            'payment_status' => 'paid',
        ]);

        $response->assertSessionHasNoErrors();

        $tenant = Tenant::where('email', 'hartono@retailsejahtera.com')->first();
        $this->assertNotNull($tenant);
        $this->assertEquals('company', $tenant->customer_type);
        $this->assertEquals('Perusahaan', $tenant->customer_type_label);
        $this->assertEquals('01.234.567.8-999.000', $tenant->tax_number);

        $tokens = LicenseToken::where('tenant_id', $tenant->id)->get();
        $this->assertCount(2, $tokens);
    }

    public function test_repeat_order_on_existing_customer_creates_additional_tokens(): void
    {
        $this->actingAs($this->admin);

        $tenant = Tenant::create([
            'name' => 'Resto Sedap Rasa',
            'customer_type' => 'individual',
            'owner_name' => 'Ibu Siti',
            'email' => 'siti@sedaprasa.com',
            'phone' => '087712345678',
            'status' => 'active',
        ]);

        $initialTenantCount = Tenant::count();

        $response = $this->post(route('admin.tenants.store'), [
            'customer_mode' => 'existing',
            'customer_id' => $tenant->id,
            'package_id' => $this->package->id,
            'quantity' => 2,
            'payment_status' => 'paid',
            'client_note' => 'Penambahan Cabang Baru',
        ]);

        $response->assertSessionHasNoErrors();
        $response->assertRedirect(route('admin.tenants.show', $tenant));

        // Ensure no new tenant created
        $this->assertEquals($initialTenantCount, Tenant::count());

        // Ensure 2 tokens created for this existing tenant
        $tokens = LicenseToken::where('tenant_id', $tenant->id)->get();
        $this->assertCount(2, $tokens);
    }

    public function test_unpaid_order_and_subsequent_payment_approval_workflow(): void
    {
        $this->actingAs($this->admin);

        $tenant = Tenant::create([
            'name' => 'Apotek Sehat Medika',
            'customer_type' => 'company',
            'owner_name' => 'Dr. Rudi',
            'email' => 'rudi@sehatmedika.com',
            'phone' => '081399887766',
            'status' => 'active',
        ]);

        // 1. Buat order dengan status UNPAID
        $response = $this->post(route('admin.tenants.store'), [
            'customer_mode' => 'existing',
            'customer_id' => $tenant->id,
            'package_id' => $this->package->id,
            'quantity' => 2,
            'payment_status' => 'unpaid',
            'client_note' => 'Invoice Pembelian 2 Lisensi',
        ]);

        $response->assertSessionHasNoErrors();

        // Assert invoice is UNPAID and 0 tokens generated yet
        $invoice = Invoice::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($invoice);
        $this->assertEquals(InvoiceStatus::UNPAID, $invoice->status);
        $this->assertEquals(0, LicenseToken::where('tenant_id', $tenant->id)->count());

        // 2. Admin Approve / Mark As Paid
        $approveResponse = $this->post(route('admin.invoices.mark-paid', $invoice->id), [
            'payment_method' => 'bank_transfer',
        ]);

        $approveResponse->assertSessionHasNoErrors();

        $invoice->refresh();
        $this->assertEquals(InvoiceStatus::PAID, $invoice->status);
        $this->assertEquals(2, LicenseToken::where('tenant_id', $tenant->id)->count());
    }

    public function test_generated_bulk_token_can_be_activated_by_mobile_pos_with_valid_signature(): void
    {
        $this->actingAs($this->admin);

        // Buat order bulk 2 lisensi
        $this->post(route('admin.tenants.store'), [
            'customer_mode' => 'new',
            'customer_type' => 'individual',
            'name' => 'Toko Barokah Elektronik',
            'owner_name' => 'Haji Mansur',
            'email' => 'mansur@barokah.com',
            'password' => 'password123',
            'package_id' => $this->package->id,
            'quantity' => 2,
            'payment_status' => 'paid',
        ]);

        $tenant = Tenant::where('email', 'mansur@barokah.com')->first();
        $user = User::where('email', 'mansur@barokah.com')->first();
        $tokens = LicenseToken::where('tenant_id', $tenant->id)->get();
        $this->assertCount(2, $tokens);

        $firstToken = $tokens->first();

        // Uji aktivasi lisensi dari aplikasi Mobile POS via /api/activate
        $activationResponse = $this->actingAs($user, 'sanctum')->postJson('/api/activate', [
            'token_key' => $firstToken->token_key,
            'device_id' => 'DEVICE-POS-CASHIER-01',
            'fingerprint_hash' => hash('sha256', 'DEVICE-POS-CASHIER-01-HW-CPU'),
            'device_info' => [
                'model' => 'Sunmi T2 Mini',
                'brand' => 'Sunmi',
                'os_version' => 'Android 11',
            ],
        ]);

        $activationResponse->assertStatus(200)
            ->assertJsonPath('success', true);

        $jwt = $activationResponse->json('offline_token');
        $this->assertNotEmpty($jwt);

        $firstToken->refresh();
        $this->assertEquals(TokenStatus::ACTIVE, $firstToken->status);
        $this->assertNotNull($firstToken->activated_at);
        $this->assertNotNull($firstToken->activeDevice);
        $this->assertEquals('DEVICE-POS-CASHIER-01-HW-CPU', hash('sha256', 'DEVICE-POS-CASHIER-01-HW-CPU') === $firstToken->activeDevice->fingerprint_hash ? 'DEVICE-POS-CASHIER-01-HW-CPU' : '');
    }
}
