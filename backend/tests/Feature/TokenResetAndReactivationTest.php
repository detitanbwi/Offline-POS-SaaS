<?php

namespace Tests\Feature;

use App\Enums\DeviceStatus;
use App\Enums\InvoiceStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\Device;
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

class TokenResetAndReactivationTest extends TestCase
{
    use RefreshDatabase;

    protected Tenant $tenant;
    protected User $user;
    protected User $admin;
    protected LicenseToken $token;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        $this->tenant = Tenant::create([
            'name' => 'Toko Sentosa',
            'owner_name' => 'Budi',
            'email' => 'sentosa@example.com',
            'status' => 'active',
        ]);

        $this->user = User::create([
            'name' => 'Kasir Sentosa',
            'email' => 'kasir@sentosa.com',
            'password' => Hash::make('password123'),
            'tenant_id' => $this->tenant->id,
        ]);

        $this->admin = User::create([
            'name' => 'Super Admin',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password123'),
            'is_admin' => true,
        ]);

        $package = Package::create([
            'name' => 'Pro Package',
            'slug' => 'pro-package',
            'price' => 350000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);

        $subscription = Subscription::create([
            'tenant_id' => $this->tenant->id,
            'package_id' => $package->id,
            'package_name' => $package->name,
            'status' => SubscriptionStatus::ACTIVE,
            'start_date' => now()->toDateString(),
            'expiry_date' => now()->addDays(365)->toDateString(),
        ]);

        $this->token = LicenseToken::create([
            'subscription_id' => $subscription->id,
            'tenant_id' => $this->tenant->id,
            'token_key' => 'WDEV-PRO-TEST-RESET-01',
            'server_secret' => 'secret_key_123',
            'status' => TokenStatus::AVAILABLE,
        ]);
    }

    public function test_reset_token_allows_reactivation_on_new_device(): void
    {
        $apiToken = $this->user->createToken('test-token')->plainTextToken;

        // 1. Activate on Device A (Phone A)
        $fingerprintA = hash('sha256', 'device_a_fingerprint');
        $response1 = $this->withHeaders([
            'Authorization' => "Bearer $apiToken",
        ])->postJson('/api/activate', [
            'token_key' => $this->token->token_key,
            'fingerprint_hash' => $fingerprintA,
            'brand' => 'Samsung',
            'model' => 'Galaxy S21',
        ]);

        $response1->assertStatus(200)
            ->assertJsonPath('success', true);

        $this->token->refresh();
        $this->assertEquals(TokenStatus::ACTIVE, $this->token->status);

        // 2. Attempt activate on Device B without reset -> SHOULD FAIL
        $fingerprintB = hash('sha256', 'device_b_fingerprint');
        $responseFailed = $this->withHeaders([
            'Authorization' => "Bearer $apiToken",
        ])->postJson('/api/activate', [
            'token_key' => $this->token->token_key,
            'fingerprint_hash' => $fingerprintB,
            'brand' => 'Xiaomi',
            'model' => 'Redmi Note 10',
        ]);

        $responseFailed->assertStatus(400)
            ->assertJsonPath('success', false);

        // 3. Admin resets the device via POST route
        $this->actingAs($this->admin);
        $resetResponse = $this->post(route('admin.tokens.reset-device', $this->token));
        $resetResponse->assertRedirect();

        $this->token->refresh();
        $this->assertEquals(TokenStatus::AVAILABLE, $this->token->status);

        $deviceA = Device::where('fingerprint_hash', $fingerprintA)->first();
        $this->assertNotNull($deviceA);
        $this->assertEquals(DeviceStatus::DEACTIVATED, $deviceA->status);

        // 4. Activate on Device B after reset -> MUST SUCCEED NOW!
        $response2 = $this->withHeaders([
            'Authorization' => "Bearer $apiToken",
        ])->postJson('/api/activate', [
            'token_key' => $this->token->token_key,
            'fingerprint_hash' => $fingerprintB,
            'brand' => 'Xiaomi',
            'model' => 'Redmi Note 10',
        ]);

        $response2->assertStatus(200)
            ->assertJsonPath('success', true);

        $this->token->refresh();
        $this->assertEquals(TokenStatus::ACTIVE, $this->token->status);

        $deviceB = Device::where('fingerprint_hash', $fingerprintB)->first();
        $this->assertNotNull($deviceB);
        $this->assertEquals(DeviceStatus::ACTIVE, $deviceB->status);
    }
}
