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

class ActivationControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_returns_only_safe_user_fields(): void
    {
        $user = User::factory()->create([
            'email' => 'kasir@example.com',
            'password' => Hash::make('secret123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'kasir@example.com',
            'password' => 'secret123',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'message',
                'access_token',
                'user' => [
                    'id',
                    'name',
                    'email',
                ],
            ]);

        // Assert it does NOT return password/remember_token/etc
        $userResponse = $response->json('user');
        $this->assertArrayNotHasKey('password', $userResponse);
        $this->assertArrayNotHasKey('is_admin', $userResponse);
        $this->assertArrayNotHasKey('tenant_id', $userResponse);
    }

    public function test_activate_device_does_not_leak_server_secret(): void
    {
        // 1. Setup Tenant and User
        $tenant = Tenant::create([
            'name' => 'Wirodev Store',
            'owner_name' => 'Wiro',
            'email' => 'wiro@example.com',
            'status' => 'active',
        ]);

        $user = User::create([
            'name' => 'Kasir Wiro',
            'email' => 'kasir@example.com',
            'password' => Hash::make('secret123'),
            'tenant_id' => $tenant->id,
        ]);

        // 2. Setup Package, Invoice, Subscription & License Token
        $package = Package::create([
            'name' => 'Pro Package',
            'slug' => 'pro-package',
            'price' => 350000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);

        $invoice = Invoice::create([
            'tenant_id' => $tenant->id,
            'invoice_number' => 'INV-TEST-0001',
            'status' => InvoiceStatus::PAID,
            'subtotal' => 350000,
            'total_amount' => 350000,
            'paid_at' => now(),
        ]);

        $invoiceItem = InvoiceItem::create([
            'invoice_id' => $invoice->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'quantity' => 1,
            'duration_days' => 365,
            'unit_price' => 350000,
            'total_price' => 350000,
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

        $token = LicenseToken::create([
            'subscription_id' => $subscription->id,
            'tenant_id' => $tenant->id,
            'token_key' => 'POS-PRO-TEST-KEY-123',
            'server_secret' => 'super_secret_never_expose_this',
            'status' => TokenStatus::AVAILABLE,
        ]);

        // Set JWT_SECRET in config for JWT signature generation in test
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        // 3. Authenticate with Sanctum
        $apiToken = $user->createToken('test-token')->plainTextToken;

        // 4. Request activation
        $response = $this->withHeaders([
            'Authorization' => "Bearer $apiToken",
        ])->postJson('/api/activate', [
            'token_key' => 'POS-PRO-TEST-KEY-123',
            'fingerprint_hash' => hash('sha256', 'dummy_hash_123'),
            'android_id_hash' => hash('sha256', 'android_id_123'),
            'manufacturer' => 'SaaSBrand',
            'brand' => 'SaaSBrand',
            'model' => 'Model S',
            'installation_uuid_hash' => hash('sha256', 'install_123'),
        ]);

        // 5. Assert response does NOT contain server_secret
        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'message',
                'offline_token',
                'expires_at',
            ]);

        $response->assertJsonMissing([
            'server_secret' => 'super_secret_never_expose_this',
        ]);

        $this->assertArrayNotHasKey('server_secret', $response->json());
    }
}
