<?php

namespace Tests\Feature;

use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class TenantProvisioningAndGeneratorTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        Package::create([
            'name' => 'Pro Plan',
            'slug' => 'pro-plan',
            'price' => 350000,
            'default_duration_days' => 365,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);
    }

    public function test_tenant_creation_auto_provisions_user_subscription_and_token(): void
    {
        $admin = User::create([
            'name' => 'Admin SaaS',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $this->actingAs($admin);

        $response = $this->post(route('admin.tenants.store'), [
            'name' => 'Kopi Mantan',
            'owner_name' => 'Budi Santoso',
            'email' => 'budi@kopi.com',
            'password' => 'password123',
            'phone' => '081234567890',
            'store_name' => 'Kopi Mantan Outlet 1',
            'store_address' => 'Jl. Sudirman 45',
            'duration_days' => 365,
        ]);

        $response->assertSessionHasNoErrors();
        $response->assertRedirect();

        // Assert Tenant created
        $tenant = Tenant::where('email', 'budi@kopi.com')->first();
        $this->assertNotNull($tenant);

        // Assert User created
        $user = User::where('email', 'budi@kopi.com')->first();
        $this->assertNotNull($user);
        $this->assertEquals($tenant->id, $user->tenant_id);
        $this->assertTrue(Hash::check('password123', $user->password));

        // Assert Subscription created
        $subscription = Subscription::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($subscription);
        $this->assertEquals(SubscriptionStatus::ACTIVE, $subscription->status);

        // Assert Token created
        $token = LicenseToken::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($token);
        $this->assertEquals(TokenStatus::AVAILABLE, $token->status);

        // Test login API for new tenant user
        $loginResponse = $this->postJson('/api/login', [
            'email' => 'budi@kopi.com',
            'password' => 'password123',
        ]);
        $this->assertEquals(200, $loginResponse->status(), 'Login failed: '.$loginResponse->getContent());

        $loginResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('tenant.store_name', 'Kopi Mantan Outlet 1')
            ->assertJsonPath('tenant.store_address', 'Jl. Sudirman 45')
            ->assertJsonPath('license_tokens.0.token_key', $token->token_key);

        // Test GET /api/license-info API endpoint
        $apiToken = $loginResponse->json('access_token');
        $infoResponse = $this->actingAs($user, 'sanctum')->getJson('/api/license-info');

        $infoResponse->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('tenant.store_name', 'Kopi Mantan Outlet 1')
            ->assertJsonPath('tokens.0.token_key', $token->token_key);
    }

    public function test_generator_lisensi_updates_expiry_date_and_generates_new_token(): void
    {
        $admin = User::create([
            'name' => 'Admin SaaS',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $tenant = Tenant::create([
            'name' => 'Kopi Mantan',
            'owner_name' => 'Budi Santoso',
            'email' => 'budi@kopi.com',
            'status' => 'active',
        ]);

        $this->actingAs($admin);

        $newExpiry = now()->addYear()->format('Y-m-d');
        $response = $this->post(route('admin.tenants.generate-license', $tenant), [
            'expiry_date' => $newExpiry,
            'client_note' => 'Perpanjangan Paket 1 Tahun',
        ]);

        $response->assertRedirect();

        $subscription = Subscription::where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($subscription);
        $this->assertEquals($newExpiry, $subscription->expiry_date->format('Y-m-d'));

        $token = LicenseToken::where('tenant_id', $tenant->id)->latest()->first();
        $this->assertNotNull($token);
        $this->assertEquals(TokenStatus::AVAILABLE, $token->status);
        $this->assertEquals('Perpanjangan Paket 1 Tahun', $token->client_note);
    }
}
