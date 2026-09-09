<?php

namespace Tests\Feature;

use App\Models\Device;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Role;
use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RbacAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected User $superAdmin;
    protected User $operator;
    protected Tenant $tenant;
    protected Package $package;
    protected LicenseToken $token;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RoleSeeder::class);

        $superAdminRole = Role::where('slug', 'super_admin')->first();
        $operatorRole = Role::where('slug', 'operator')->first();

        $this->superAdmin = User::updateOrCreate(
            ['email' => 'admin@possaas.com'],
            [
                'name' => 'Admin Super',
                'password' => 'password',
                'is_admin' => true,
                'role_id' => $superAdminRole->id,
            ]
        );

        $this->operator = User::updateOrCreate(
            ['email' => 'operator@possaas.com'],
            [
                'name' => 'Operator Staff',
                'password' => 'password',
                'is_admin' => true,
                'role_id' => $operatorRole->id,
            ]
        );

        $this->tenant = Tenant::create([
            'name' => 'Test Tenant',
            'owner_name' => 'John Doe',
            'email' => 'tenant@example.com',
            'status' => \App\Enums\TenantStatus::ACTIVE,
        ]);

        $this->package = Package::create([
            'name' => 'Test Package',
            'slug' => 'test-pkg',
            'price' => 100000,
            'is_active' => true,
        ]);

        $subscription = \App\Models\Subscription::create([
            'tenant_id' => $this->tenant->id,
            'package_id' => $this->package->id,
            'package_name' => $this->package->name,
            'status' => \App\Enums\SubscriptionStatus::ACTIVE,
            'start_date' => now()->toDateString(),
            'expiry_date' => now()->addMonth()->toDateString(),
        ]);

        $this->token = LicenseToken::create([
            'tenant_id' => $this->tenant->id,
            'subscription_id' => $subscription->id,
            'token_key' => 'TEST-TOKEN-1234',
            'status' => \App\Enums\TokenStatus::ACTIVE,
            'server_secret' => 'secret123',
        ]);
    }

    public function test_operator_can_view_dashboard_and_tenants(): void
    {
        $response = $this->actingAs($this->operator)->get('/admin');
        $response->assertStatus(200);

        $response = $this->actingAs($this->operator)->get('/admin/tenants');
        $response->assertStatus(200);
    }

    public function test_operator_cannot_delete_tenant(): void
    {
        $response = $this->actingAs($this->operator)->delete('/admin/tenants/' . $this->tenant->id);
        $response->assertStatus(403);
    }

    public function test_operator_cannot_suspend_tenant(): void
    {
        $response = $this->actingAs($this->operator)->post('/admin/tenants/' . $this->tenant->id . '/suspend');
        $response->assertStatus(403);
    }

    public function test_operator_cannot_reset_license_token_device(): void
    {
        $response = $this->actingAs($this->operator)->post('/admin/tokens/' . $this->token->id . '/reset-device');
        $response->assertStatus(403);
    }

    public function test_operator_cannot_create_or_delete_packages(): void
    {
        $response = $this->actingAs($this->operator)->get('/admin/packages/create');
        $response->assertStatus(403);

        $response = $this->actingAs($this->operator)->delete('/admin/packages/' . $this->package->id);
        $response->assertStatus(403);
    }

    public function test_super_admin_can_perform_all_actions(): void
    {
        // Super admin can suspend tenant
        $response = $this->actingAs($this->superAdmin)->post('/admin/tenants/' . $this->tenant->id . '/suspend');
        $response->assertStatus(302);

        // Super admin can reset device
        $response = $this->actingAs($this->superAdmin)->post('/admin/tokens/' . $this->token->id . '/reset-device');
        $response->assertStatus(302);
    }
}
