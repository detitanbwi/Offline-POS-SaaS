<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class TenantInvoiceAndLicenseFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);
    }

    public function test_tenant_detail_displays_invoices_history_and_not_loose_generator(): void
    {
        $admin = User::create([
            'name' => 'Admin POS SaaS',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $tenant = Tenant::create([
            'name' => 'Kopi Mantan Pusat',
            'owner_name' => 'Budi Santoso',
            'email' => 'budi@kopi.com',
            'store_name' => 'Kopi Mantan Outlet 1',
            'status' => 'active',
        ]);

        $package = Package::create([
            'name' => 'Pro Plan',
            'slug' => 'pro-plan',
            'price' => 350000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);

        $invoice = Invoice::create([
            'tenant_id' => $tenant->id,
            'invoice_number' => 'INV-TEST-202609-0001',
            'status' => InvoiceStatus::PAID,
            'subtotal' => 700000,
            'total_amount' => 700000,
            'paid_at' => now(),
        ]);

        $invoiceItem = InvoiceItem::create([
            'invoice_id' => $invoice->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'quantity' => 2,
            'duration_days' => 365,
            'unit_price' => 350000,
            'total_price' => 700000,
            'client_note' => 'Tablet Kasir Utama & Barista',
        ]);

        $subscription = Subscription::create([
            'tenant_id' => $tenant->id,
            'invoice_item_id' => $invoiceItem->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'status' => SubscriptionStatus::ACTIVE,
            'start_date' => now()->toDateString(),
            'expiry_date' => now()->addDays(365)->toDateString(),
        ]);

        $token1 = LicenseToken::create([
            'subscription_id' => $subscription->id,
            'tenant_id' => $tenant->id,
            'token_key' => 'WDEV-PRO-AAA1-BBB1-2026',
            'server_secret' => 'secret1',
            'client_note' => 'Tablet Kasir Utama & Barista #1',
            'status' => TokenStatus::AVAILABLE,
        ]);

        $token2 = LicenseToken::create([
            'subscription_id' => $subscription->id,
            'tenant_id' => $tenant->id,
            'token_key' => 'WDEV-PRO-AAA2-BBB2-2026',
            'server_secret' => 'secret2',
            'client_note' => 'Tablet Kasir Utama & Barista #2',
            'status' => TokenStatus::AVAILABLE,
        ]);

        $this->actingAs($admin);

        // 1. Visit Tenant Detail Page
        $response = $this->get(route('admin.tenants.show', $tenant));
        $response->assertStatus(200);

        // Assert Invoice information is shown
        $response->assertSee('INV-TEST-202609-0001');
        $response->assertSee('Riwayat Tagihan & Pembelian Lisensi', false);
        $response->assertSee('+ Buat Invoice Baru', false);
        $response->assertSee('Buka Detail & Token', false);

        // Assert the loose generator form with submit button is NOT present
        $response->assertDontSee('Perbarui Tanggal & Generate Token Baru', false);
        $response->assertDontSee('Tanggal Kedaluwarsa Lisensi Klien', false);

        // 2. Visit Create Invoice with ?tenant_id=
        $createInvoiceResponse = $this->get(route('admin.invoices.create', ['tenant_id' => $tenant->id]));
        $createInvoiceResponse->assertStatus(200);
        $createInvoiceResponse->assertSee('value="' . $tenant->id . '" selected', false);

        // 3. Visit Invoice Detail Page
        $invoiceShowResponse = $this->get(route('admin.invoices.show', $invoice));
        $invoiceShowResponse->assertStatus(200);
        $invoiceShowResponse->assertSee($token1->token_key);
        $invoiceShowResponse->assertSee($token2->token_key);
        $invoiceShowResponse->assertSee('Tablet Kasir Utama &amp; Barista #1', false);
        $invoiceShowResponse->assertSee('Tablet Kasir Utama &amp; Barista #2', false);
        $invoiceShowResponse->assertSee('Salin');

        // 4. API Login for store user returns enriched tokens
        $storeUser = User::create([
            'tenant_id' => $tenant->id,
            'name' => 'Budi Santoso',
            'email' => 'budi@kopi.com',
            'password' => Hash::make('password123'),
            'is_admin' => false,
        ]);

        $loginResponse = $this->postJson('/api/login', [
            'email' => 'budi@kopi.com',
            'password' => 'password123',
        ]);

        $loginResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('license_tokens.0.token_key', $token1->token_key)
            ->assertJsonPath('license_tokens.0.client_note', 'Tablet Kasir Utama & Barista #1')
            ->assertJsonPath('license_tokens.0.is_bound', false)
            ->assertJsonPath('license_tokens.1.token_key', $token2->token_key)
            ->assertJsonPath('license_tokens.1.client_note', 'Tablet Kasir Utama & Barista #2')
            ->assertJsonPath('license_tokens.1.is_bound', false);
    }

    public function test_invoice_show_kembali_button_returns_to_tenant_or_invoices_based_on_origin(): void
    {
        $admin = User::create([
            'name' => 'Admin POS SaaS',
            'email' => 'admin_test_back@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $tenant = Tenant::create([
            'name' => 'Resto Sedap Rasa',
            'owner_name' => 'Siti',
            'email' => 'siti@sedap.com',
            'store_name' => 'Sedap Rasa Cabang 1',
            'status' => 'active',
        ]);

        $invoice = Invoice::create([
            'tenant_id' => $tenant->id,
            'invoice_number' => 'INV-TEST-BACK-001',
            'status' => InvoiceStatus::UNPAID,
            'subtotal' => 200000,
            'total_amount' => 200000,
        ]);

        $this->actingAs($admin);

        // 1. Accessed from Tenant detail (via return_to query parameter)
        $tenantUrl = route('admin.tenants.show', $tenant);
        $fromTenantResponse = $this->get(route('admin.invoices.show', [
            'invoice' => $invoice,
            'return_to' => $tenantUrl,
        ]));

        $fromTenantResponse->assertStatus(200);
        $fromTenantResponse->assertSee('href="' . $tenantUrl . '"', false);
        $fromTenantResponse->assertSee('Tujuan Kembali: <strong>' . $tenant->name . '</strong>', false);

        // 2. Accessed with HTTP Referer header set to Tenant detail (without explicit return_to query)
        $refererTenantResponse = $this->withHeaders(['Referer' => $tenantUrl])
            ->get(route('admin.invoices.show', $invoice));

        $refererTenantResponse->assertStatus(200);
        $refererTenantResponse->assertSee('href="' . $tenantUrl . '"', false);

        // 3. Accessed from Invoices Index (via return_to)
        $invoiceListUrl = route('admin.invoices.index', ['status' => 'unpaid']);
        $fromInvoicesResponse = $this->get(route('admin.invoices.show', [
            'invoice' => $invoice,
            'return_to' => $invoiceListUrl,
        ]));

        $fromInvoicesResponse->assertStatus(200);
        $fromInvoicesResponse->assertSee('href="' . e($invoiceListUrl) . '"', false);
        $fromInvoicesResponse->assertSee('Tujuan Kembali: <strong>Daftar Invoice</strong>', false);

        // 4. Default fallback when opened without referer / return_to
        $defaultResponse = $this->withSession([])
            ->get(route('admin.invoices.show', $invoice));
        $defaultResponse->assertStatus(200);
        $defaultResponse->assertSee('href="' . route('admin.invoices.index') . '"', false);
    }
}

