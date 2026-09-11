<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SoftDeleteAndRestoreTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Tenant $tenant;
    protected Invoice $invoice;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::create([
            'name' => 'Admin Super',
            'email' => 'admin@possaas.com',
            'password' => Hash::make('password'),
            'is_admin' => true,
        ]);

        $this->tenant = Tenant::create([
            'name' => 'Toko Barokah Jaya',
            'owner_name' => 'Ahmad',
            'email' => 'ahmad@barokah.com',
            'store_name' => 'Barokah Mart',
            'status' => 'active',
        ]);

        $this->invoice = Invoice::create([
            'tenant_id' => $this->tenant->id,
            'invoice_number' => 'INV-TEST-SOFTDELETE-01',
            'status' => InvoiceStatus::UNPAID,
            'subtotal' => 250000,
            'total_amount' => 250000,
        ]);
    }

    public function test_tenant_can_be_soft_deleted_and_restored(): void
    {
        $this->actingAs($this->admin);

        // 1. Delete Tenant (Soft Delete)
        $deleteResponse = $this->delete(route('admin.tenants.destroy', $this->tenant));
        $deleteResponse->assertRedirect(route('admin.tenants.index'));

        // Assert soft deleted
        $this->assertSoftDeleted('tenants', ['id' => $this->tenant->id]);
        $this->tenant->refresh();
        $this->assertTrue($this->tenant->trashed());

        // 2. Trashed filter lists the deleted tenant
        $trashedListResponse = $this->get(route('admin.tenants.index', ['status' => 'trashed']));
        $trashedListResponse->assertStatus(200);
        $trashedListResponse->assertSee($this->tenant->name);
        $trashedListResponse->assertSee('Terhapus');
        $trashedListResponse->assertSee('Pulihkan');

        // 3. Normal list does NOT list the deleted tenant
        $normalListResponse = $this->get(route('admin.tenants.index'));
        $normalListResponse->assertStatus(200);
        $normalListResponse->assertDontSee($this->tenant->name);

        // 4. Restore Tenant
        $restoreResponse = $this->post(route('admin.tenants.restore', $this->tenant->id));
        $restoreResponse->assertRedirect();

        // Assert restored
        $this->assertNotSoftDeleted('tenants', ['id' => $this->tenant->id]);
        $this->tenant->refresh();
        $this->assertFalse($this->tenant->trashed());

        // Now appears back in normal list
        $afterRestoreResponse = $this->get(route('admin.tenants.index'));
        $afterRestoreResponse->assertSee($this->tenant->name);
    }

    public function test_invoice_can_be_soft_deleted_and_restored(): void
    {
        $this->actingAs($this->admin);

        // 1. Delete Invoice (Soft Delete)
        $deleteResponse = $this->delete(route('admin.invoices.destroy', $this->invoice));
        $deleteResponse->assertRedirect(route('admin.invoices.index'));

        // Assert soft deleted
        $this->assertSoftDeleted('invoices', ['id' => $this->invoice->id]);
        $this->invoice->refresh();
        $this->assertTrue($this->invoice->trashed());

        // 2. Trashed filter lists the deleted invoice
        $trashedListResponse = $this->get(route('admin.invoices.index', ['status' => 'trashed']));
        $trashedListResponse->assertStatus(200);
        $trashedListResponse->assertSee($this->invoice->invoice_number);
        $trashedListResponse->assertSee('Terhapus');
        $trashedListResponse->assertSee('Pulihkan');

        // 3. Normal list does NOT list the deleted invoice
        $normalListResponse = $this->get(route('admin.invoices.index'));
        $normalListResponse->assertStatus(200);
        $normalListResponse->assertDontSee($this->invoice->invoice_number);

        // 4. Viewing trashed invoice works and shows warning banner
        $showTrashedResponse = $this->get(route('admin.invoices.show', $this->invoice));
        $showTrashedResponse->assertStatus(200);
        $showTrashedResponse->assertSee('Perhatian: Invoice ini berada di tempat sampah (Soft Deleted)');

        // 5. Restore Invoice
        $restoreResponse = $this->post(route('admin.invoices.restore', $this->invoice->id));
        $restoreResponse->assertRedirect();

        // Assert restored
        $this->assertNotSoftDeleted('invoices', ['id' => $this->invoice->id]);
        $this->invoice->refresh();
        $this->assertFalse($this->invoice->trashed());

        // Now appears back in normal list
        $afterRestoreResponse = $this->get(route('admin.invoices.index'));
        $afterRestoreResponse->assertSee($this->invoice->invoice_number);
    }

    public function test_trash_center_page_displays_trashed_tenants_and_invoices(): void
    {
        $this->actingAs($this->admin);

        // Initially trash should show empty messages
        $emptyResponse = $this->get(route('admin.trash.index', ['tab' => 'tenants']));
        $emptyResponse->assertStatus(200);
        $emptyResponse->assertSee('Tempat sampah tenant kosong.');

        $emptyInvoiceResponse = $this->get(route('admin.trash.index', ['tab' => 'invoices']));
        $emptyInvoiceResponse->assertStatus(200);
        $emptyInvoiceResponse->assertSee('Tempat sampah invoice kosong.');

        // Soft delete tenant and invoice
        $this->tenant->delete();
        $this->invoice->delete();

        // 1. Check Tenants tab in Trash Center
        $trashTenantsResponse = $this->get(route('admin.trash.index', ['tab' => 'tenants']));
        $trashTenantsResponse->assertStatus(200);
        $trashTenantsResponse->assertSee($this->tenant->name);
        $trashTenantsResponse->assertSee('Pulihkan Tenant');

        // 2. Check Invoices tab in Trash Center
        $trashInvoicesResponse = $this->get(route('admin.trash.index', ['tab' => 'invoices']));
        $trashInvoicesResponse->assertStatus(200);
        $trashInvoicesResponse->assertSee($this->invoice->invoice_number);
        $trashInvoicesResponse->assertSee('Pulihkan');

        // 3. Test Search in Trash Center
        $searchTenantResponse = $this->get(route('admin.trash.index', ['tab' => 'tenants', 'search' => 'Barokah']));
        $searchTenantResponse->assertStatus(200);
        $searchTenantResponse->assertSee($this->tenant->name);

        $searchNoneResponse = $this->get(route('admin.trash.index', ['tab' => 'tenants', 'search' => 'NonExistentXYZ']));
        $searchNoneResponse->assertStatus(200);
        $searchNoneResponse->assertDontSee($this->tenant->name);
    }
}

