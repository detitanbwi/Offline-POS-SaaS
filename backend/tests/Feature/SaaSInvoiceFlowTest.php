<?php

namespace Tests\Feature;

use App\Enums\DeviceStatus;
use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\Device;
use App\Models\Invoice;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SaaSInvoiceFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);
    }

    public function test_complete_invoice_to_activation_flow(): void
    {
        // 1. Setup Tenant and Owner/Cashier user
        $tenant = Tenant::create([
            'name' => 'Wirodev POS Store',
            'owner_name' => 'Wiro Owner',
            'email' => 'wiro.owner@example.com',
            'status' => 'active',
        ]);

        $adminUser = User::create([
            'name' => 'Admin POS SaaS',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $cashierUser = User::create([
            'name' => 'Kasir Wiro',
            'email' => 'kasir@example.com',
            'password' => Hash::make('secret123'),
            'tenant_id' => $tenant->id,
            'is_admin' => false,
        ]);

        // 2. Setup Packages
        $proPackage = Package::create([
            'name' => 'Pro Plan',
            'slug' => 'pro-plan',
            'price' => 350000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);

        // 3. Admin creates invoice for tenant
        $this->actingAs($adminUser);

        $createResponse = $this->post(route('admin.invoices.store'), [
            'tenant_id' => $tenant->id,
            'items' => [
                [
                    'package_id' => $proPackage->id,
                    'quantity' => 2, // 2 Licenses
                    'duration_days' => 365,
                ],
            ],
            'notes' => 'Invoice pembelian 2 lisensi Pro Plan',
        ]);

        $createResponse->assertRedirect();

        $invoice = Invoice::orderBy('created_at', 'desc')->first();
        $this->assertNotNull($invoice);
        $this->assertEquals(InvoiceStatus::UNPAID, $invoice->status);
        $this->assertEquals(700000, $invoice->total_amount); // 2 * 350000
        $this->assertCount(1, $invoice->items);

        // 4. Admin confirms payment for the invoice
        $payResponse = $this->post(route('admin.invoices.mark-paid', $invoice), [
            'payment_method' => 'qris',
        ]);

        $payResponse->assertRedirect();

        $invoice->refresh();
        $this->assertEquals(InvoiceStatus::PAID, $invoice->status);
        $this->assertEquals('qris', $invoice->payment_method);
        $this->assertNotNull($invoice->paid_at);

        // 5. Verify Subscription was created
        $subscription = Subscription::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($subscription);
        $this->assertEquals(SubscriptionStatus::ACTIVE, $subscription->status);
        $this->assertEquals($proPackage->name, $subscription->package_name);
        $this->assertEquals(now()->toDateString(), $subscription->start_date->toDateString());
        $this->assertEquals(now()->addDays(365)->toDateString(), $subscription->expiry_date->toDateString());

        // 6. Verify 2 LicenseTokens were generated
        $tokens = LicenseToken::where('subscription_id', $subscription->id)->get();
        $this->assertCount(2, $tokens);
        foreach ($tokens as $token) {
            $this->assertEquals(TokenStatus::AVAILABLE, $token->status);
            $this->assertStringStartsWith('WDEV-PRO-', $token->token_key);
        }

        // 7. Cashier activates first device using the first token key
        $activeToken = $tokens[0];
        $cashierToken = $cashierUser->createToken('cashier-api')->plainTextToken;

        $activationPayload = [
            'token_key' => $activeToken->token_key,
            'fingerprint_hash' => hash('sha256', 'device_fingerprint_01'),
            'android_id_hash' => hash('sha256', 'android_id_01'),
            'manufacturer' => 'Samsung',
            'brand' => 'Samsung',
            'model' => 'Galaxy S21',
            'installation_uuid_hash' => hash('sha256', 'installation_uuid_01'),
        ];

        $activateResponse = $this->withHeaders([
            'Authorization' => "Bearer $cashierToken",
        ])->postJson('/api/activate', $activationPayload);

        $activateResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['success', 'message', 'offline_token', 'expires_at']);

        // Verify database state after activation
        $activeToken->refresh();
        $this->assertEquals(TokenStatus::ACTIVE, $activeToken->status);
        $this->assertNotNull($activeToken->activated_at);

        $device = Device::where('license_token_id', $activeToken->id)->first();
        $this->assertNotNull($device);
        $this->assertEquals(DeviceStatus::ACTIVE, $device->status);
        $this->assertEquals(hash('sha256', 'device_fingerprint_01'), $device->fingerprint_hash);
        $this->assertEquals('Samsung Galaxy S21', $device->display_name);

        // 8. Re-activation with same token and same fingerprint should succeed
        $reActivateResponse = $this->withHeaders([
            'Authorization' => "Bearer $cashierToken",
        ])->postJson('/api/activate', $activationPayload);

        $reActivateResponse->assertStatus(200)
            ->assertJsonPath('success', true);

        // 9. Re-activation with same token but different fingerprint should fail (1 token = 1 device)
        $differentDevicePayload = $activationPayload;
        $differentDevicePayload['fingerprint_hash'] = hash('sha256', 'device_fingerprint_different');

        $failResponse = $this->withHeaders([
            'Authorization' => "Bearer $cashierToken",
        ])->postJson('/api/activate', $differentDevicePayload);

        $failResponse->assertStatus(400)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Token sudah digunakan pada perangkat lain. Harap membeli lisensi lagi.');
    }
}
