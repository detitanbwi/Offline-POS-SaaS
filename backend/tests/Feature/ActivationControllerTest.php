<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Tenant;
use App\Models\Subscription;
use App\Models\License;
use App\Models\Device;
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
                         'email'
                     ]
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
            'id' => 'tenant-1',
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

        // 2. Setup Subscription & License
        $subscription = Subscription::create([
            'id' => 'sub-1',
            'tenant_id' => $tenant->id,
            'plan' => 'lifetime',
            'status' => 'active',
            'starts_at' => now(),
            'expires_at' => now()->addYears(10),
        ]);

        $license = License::create([
            'tenant_id' => $tenant->id,
            'subscription_id' => $subscription->id,
            'license_key' => 'LIC-TEST-KEY-123',
            'device_limit' => 2,
            'device_count' => 0,
            'server_secret' => 'super_secret_never_expose_this',
            'status' => 'AVAILABLE',
            'expires_at' => now()->addYears(10),
        ]);

        // 3. Authenticate with Sanctum
        $token = $user->createToken('test-token')->plainTextToken;

        // 4. Request activation
        $response = $this->withHeaders([
            'Authorization' => "Bearer $token",
        ])->postJson('/api/activate', [
            'license_key' => 'LIC-TEST-KEY-123',
            'fingerprint_hash' => hash('sha256', 'dummy_hash_123'),
            'device_name' => 'Test Phone',
            'device_model' => 'Model S',
            'device_brand' => 'SaaSBrand',
        ]);

        // 5. Assert response does NOT contain server_secret
        $response->assertStatus(200)
                 ->assertJsonPath('success', true)
                 ->assertJsonStructure([
                     'success',
                     'message',
                     'offline_token',
                     'expires_at'
                 ]);

        $response->assertJsonMissing([
            'server_secret' => 'super_secret_never_expose_this'
        ]);
        
        $this->assertArrayNotHasKey('server_secret', $response->json());
    }
}
