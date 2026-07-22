<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use App\Models\Package;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminProfileAndPaymentProofTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Tenant $tenant;
    protected Package $package;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.jwt_secret' => 'test-jwt-secret-key-32-characters-minimum']);

        $this->admin = User::create([
            'name' => 'Admin SaaS Test',
            'email' => 'admin.test@possaas.com',
            'password' => Hash::make('password123'),
            'is_admin' => true,
        ]);

        $this->tenant = Tenant::create([
            'name' => 'Toko Barokah',
            'owner_name' => 'Haji Fulan',
            'email' => 'fulan@barokah.com',
            'status' => 'active',
        ]);

        $this->package = Package::create([
            'name' => 'Basic POS Plan',
            'slug' => 'basic-pos',
            'price' => 150000,
            'default_duration_days' => 30,
            'device_limit_per_token' => 1,
            'is_active' => true,
        ]);
    }

    public function test_invoice_creation_is_unpaid_and_allows_unpaid_pdf_download(): void
    {
        $this->actingAs($this->admin);

        $response = $this->post(route('admin.invoices.store'), [
            'tenant_id' => $this->tenant->id,
            'items' => [
                [
                    'package_id' => $this->package->id,
                    'quantity' => 1,
                    'duration_days' => 30,
                ],
            ],
            'notes' => 'Pembelian paket basic',
        ]);

        $response->assertRedirect();
        $invoice = Invoice::latest()->first();

        $this->assertNotNull($invoice);
        $this->assertEquals(InvoiceStatus::UNPAID, $invoice->status);
        $this->assertNull($invoice->payment_proof);

        // Test PDF download for UNPAID invoice
        $pdfResponse = $this->get(route('admin.invoices.download-pdf', $invoice));
        $pdfResponse->assertStatus(200);
        $pdfResponse->assertHeader('content-type', 'application/pdf');
    }

    public function test_admin_can_upload_payment_proof_for_unpaid_invoice(): void
    {
        Storage::fake('public');
        $this->actingAs($this->admin);

        $invoice = Invoice::create([
            'tenant_id' => $this->tenant->id,
            'invoice_number' => Invoice::generateInvoiceNumber(),
            'status' => InvoiceStatus::UNPAID,
            'subtotal' => 150000,
            'total_amount' => 150000,
        ]);

        $file = UploadedFile::fake()->image('bukti_transfer.jpg');

        $response = $this->post(route('admin.invoices.upload-proof', $invoice), [
            'payment_proof' => $file,
        ]);

        $response->assertRedirect();
        $invoice->refresh();

        $this->assertNotNull($invoice->payment_proof);
        Storage::disk('public')->assertExists($invoice->payment_proof);
    }

    public function test_admin_approval_marks_invoice_paid_and_generates_tokens(): void
    {
        Storage::fake('public');
        $this->actingAs($this->admin);

        $invoice = Invoice::create([
            'tenant_id' => $this->tenant->id,
            'invoice_number' => Invoice::generateInvoiceNumber(),
            'status' => InvoiceStatus::UNPAID,
            'subtotal' => 150000,
            'total_amount' => 150000,
        ]);

        $invoice->items()->create([
            'package_id' => $this->package->id,
            'package_name' => $this->package->name,
            'quantity' => 1,
            'duration_days' => 30,
            'unit_price' => 150000,
            'total_price' => 150000,
        ]);

        $proofFile = UploadedFile::fake()->image('bukti_tf.png');

        $response = $this->post(route('admin.invoices.mark-paid', $invoice), [
            'payment_method' => 'bank_transfer',
            'payment_proof' => $proofFile,
        ]);

        $response->assertRedirect();
        $invoice->refresh();

        $this->assertEquals(InvoiceStatus::PAID, $invoice->status);
        $this->assertEquals('bank_transfer', $invoice->payment_method);
        $this->assertNotNull($invoice->paid_at);
        $this->assertNotNull($invoice->payment_proof);
        Storage::disk('public')->assertExists($invoice->payment_proof);
        $this->assertCount(1, $invoice->subscriptions);

        // Test PDF download for PAID invoice
        $pdfResponse = $this->get(route('admin.invoices.download-pdf', $invoice));
        $pdfResponse->assertStatus(200);
        $pdfResponse->assertHeader('content-type', 'application/pdf');
    }

    public function test_admin_can_update_profile_login_data(): void
    {
        $this->actingAs($this->admin);

        $response = $this->put(route('admin.profile.update'), [
            'name' => 'Admin SaaS Updated',
            'email' => 'admin.newemail@possaas.com',
            'current_password' => 'password123',
            'password' => 'newpassword123',
            'password_confirmation' => 'newpassword123',
        ]);

        $response->assertRedirect();
        $this->admin->refresh();

        $this->assertEquals('Admin SaaS Updated', $this->admin->name);
        $this->assertEquals('admin.newemail@possaas.com', $this->admin->email);
        $this->assertTrue(Hash::check('newpassword123', $this->admin->password));
    }
}
