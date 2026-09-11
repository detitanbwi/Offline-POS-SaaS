<?php

namespace App\Http\Controllers;

use App\Enums\SubscriptionStatus;
use App\Enums\TenantStatus;
use App\Enums\TokenStatus;
use App\Http\Requests\StoreLicenseOrderRequest;
use App\Http\Requests\UpdateTenantRequest;
use App\Models\AuditLog;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use App\Repositories\TenantRepository;
use App\Services\InvoiceService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TenantController extends Controller
{
    public function __construct(
        protected TenantRepository $tenantRepository,
        protected InvoiceService $invoiceService,
    ) {}

    public function index()
    {
        $tenants = $this->tenantRepository->paginate(request()->only(['search', 'status']));
        $statuses = TenantStatus::cases();

        return view('admin.tenants.index', compact('tenants', 'statuses'));
    }

    public function create()
    {
        $packages = Package::where('is_active', true)->get();
        $customers = Tenant::orderBy('name')->get();

        return view('admin.tenants.create', compact('packages', 'customers'));
    }

    public function store(StoreLicenseOrderRequest $request)
    {
        return DB::transaction(function () use ($request) {
            $mode = $request->input('customer_mode', 'new');

            if ($mode === 'new') {
                $customerData = [
                    'name' => $request->input('name'),
                    'customer_type' => $request->input('customer_type', 'individual'),
                    'tax_number' => $request->input('tax_number'),
                    'owner_name' => $request->input('owner_name'),
                    'email' => $request->input('email'),
                    'phone' => $request->input('phone'),
                    'store_name' => $request->input('store_name'),
                    'store_address' => $request->input('store_address'),
                    'city' => $request->input('city'),
                    'postal_code' => $request->input('postal_code'),
                    'status' => TenantStatus::ACTIVE,
                ];

                $tenant = $this->tenantRepository->create($customerData);

                // 1. Buat User Kredensial Pemilik
                $password = $request->input('password');
                User::create([
                    'tenant_id' => $tenant->id,
                    'name' => $tenant->owner_name,
                    'email' => $tenant->email,
                    'password' => $password,
                    'is_admin' => false,
                ]);
            } else {
                $tenant = Tenant::findOrFail($request->input('customer_id'));
            }

            // 2. Otomasi Provisioning Invoice, Subscription & Token Lisensi
            $package = Package::findOrFail($request->input('package_id'));
            $quantity = (int) $request->input('quantity', 1);
            $paymentStatus = $request->input('payment_status', 'paid');
            $clientNote = $request->input('client_note');

            $invoice = $this->invoiceService->createInvoice($tenant->id, [
                [
                    'package_id' => $package->id,
                    'quantity' => $quantity,
                    'duration_days' => $package->default_duration_days,
                    'client_note' => $clientNote ?? ($mode === 'new' ? 'Pendaftaran Lisensi Perdana' : 'Penambahan Lisensi Perangkat'),
                ]
            ], $mode === 'new' ? 'Pendaftaran pelanggan baru & pemesanan lisensi.' : 'Pemesanan lisensi tambahan.');

            $tokenKeys = [];
            if ($paymentStatus === 'paid') {
                $invoice = $this->invoiceService->markAsPaid($invoice, 'Direct Admin Provisioning');
                foreach ($invoice->subscriptions as $sub) {
                    foreach ($sub->licenseTokens as $t) {
                        $tokenKeys[] = $t->token_key;
                    }
                }
            }

            $tokensSummary = count($tokenKeys) > 0 ? ' Token Lisensi: ' . implode(', ', $tokenKeys) : ' (Menunggu Pembayaran Invoice)';

            AuditLog::create([
                'action' => 'customer_license_order',
                'tenant_id' => $tenant->id,
                'details' => "Pemesanan {$quantity} lisensi paket {$package->name} untuk pelanggan {$tenant->name} ({$invoice->invoice_number}). Status: {$paymentStatus}.{$tokensSummary}",
            ]);

            return redirect()->route('admin.tenants.show', $tenant)
                ->with('success', "Pemesanan lisensi berhasil diproses! Invoice {$invoice->invoice_number} terbit untuk {$tenant->name} ({$quantity} unit {$package->name}).{$tokensSummary}");
        });
    }

    public function show(Tenant $tenant)
    {
        $tenant->load([
            'invoices' => function ($q) {
                $q->latest();
            },
            'invoices.items.package',
            'invoices.subscriptions.licenseTokens.device',
            'subscriptions' => function ($q) {
                $q->latest();
            },
            'subscriptions.package',
            'devices' => function ($q) {
                $q->latest();
            },
            'devices.licenseToken',
        ]);

        return view('admin.tenants.show', compact('tenant'));
    }

    public function edit(Tenant $tenant)
    {
        return view('admin.tenants.edit', compact('tenant'));
    }

    public function update(UpdateTenantRequest $request, Tenant $tenant)
    {
        return DB::transaction(function () use ($request, $tenant) {
            $data = $request->validated();
            $oldEmail = $tenant->email;
            $hasNewPassword = $request->filled('password');

            // Hapus password dari data tenant karena bukan kolom di tabel tenants
            unset($data['password'], $data['password_confirmation']);

            $this->tenantRepository->update($tenant, $data);

            // Sinkronisasi data user tenant yang terhubung
            $user = $tenant->users()->first();
            if (!$user) {
                $user = User::where('email', $oldEmail)->first();
            }

            $userUpdates = [
                'name' => $tenant->owner_name,
                'email' => $tenant->email,
            ];

            if ($hasNewPassword) {
                $userUpdates['password'] = $request->input('password');
            }

            if ($user) {
                $user->update($userUpdates);
            } elseif ($hasNewPassword) {
                User::create([
                    'tenant_id' => $tenant->id,
                    'name' => $tenant->owner_name,
                    'email' => $tenant->email,
                    'password' => $request->input('password'),
                    'is_admin' => false,
                ]);
            }

            if ($hasNewPassword) {
                AuditLog::create([
                    'action' => 'tenant_password_reset',
                    'tenant_id' => $tenant->id,
                    'details' => "Password untuk user tenant {$tenant->name} ({$tenant->email}) direset oleh Admin.",
                ]);
            }

            $successMsg = 'Tenant berhasil diperbarui!' . ($hasNewPassword ? ' Password user berhasil direset.' : '');

            return redirect()->route('admin.tenants.index')
                ->with('success', $successMsg);
        });
    }

    public function destroy(Tenant $tenant)
    {
        $tenantName = $tenant->name;
        $this->tenantRepository->delete($tenant);

        AuditLog::create([
            'action' => 'tenant_deleted',
            'tenant_id' => $tenant->id,
            'details' => "Tenant {$tenantName} dihapus (Soft Delete ke tempat sampah).",
        ]);

        return redirect()->route('admin.tenants.index')
            ->with('success', "Tenant {$tenantName} berhasil dihapus (tersimpan di tempat sampah)!");
    }

    public function restore(string $id)
    {
        $tenant = $this->tenantRepository->restore($id);

        AuditLog::create([
            'action' => 'tenant_restored',
            'tenant_id' => $tenant->id,
            'details' => "Tenant {$tenant->name} berhasil dipulihkan dari tempat sampah.",
        ]);

        return redirect()->back()
            ->with('success', "Tenant {$tenant->name} berhasil dipulihkan (Restore)!");
    }

    public function suspend(Tenant $tenant)
    {
        $this->tenantRepository->update($tenant, ['status' => TenantStatus::SUSPENDED]);

        return redirect()->back()
            ->with('success', 'Tenant berhasil ditangguhkan!');
    }

    public function reactivate(Tenant $tenant)
    {
        $this->tenantRepository->update($tenant, ['status' => TenantStatus::ACTIVE]);

        return redirect()->back()
            ->with('success', 'Tenant berhasil diaktifkan kembali!');
    }

    /**
     * Generator Lisensi: Update tanggal kadaluarsa & terbitkan token baru.
     */
    public function generateLicense(Request $request, Tenant $tenant)
    {
        $request->validate([
            'expiry_date' => 'required|date',
            'client_note' => 'nullable|string|max:255',
        ]);

        return DB::transaction(function () use ($request, $tenant) {
            $expiryDate = Carbon::parse($request->input('expiry_date'));
            $package = Package::where('is_active', true)->first();

            // 1. Update/Buat Subscription Aktif
            $subscription = $tenant->subscriptions()->where('status', SubscriptionStatus::ACTIVE)->first();
            if ($subscription) {
                $subscription->update([
                    'expiry_date' => $expiryDate,
                    'status' => SubscriptionStatus::ACTIVE,
                ]);
            } else {
                $subscription = Subscription::create([
                    'tenant_id' => $tenant->id,
                    'invoice_item_id' => null,
                    'package_id' => $package?->id,
                    'package_name' => $package?->name ?? 'Pro Plan',
                    'status' => SubscriptionStatus::ACTIVE,
                    'start_date' => now()->toDateString(),
                    'expiry_date' => $expiryDate->toDateString(),
                ]);
            }

            // Pulihkan status token yang terikat pada subscription ini jika dulu expired
            $tenant->licenseTokens()
                ->where('subscription_id', $subscription->id)
                ->where('status', TokenStatus::EXPIRED)
                ->update(['status' => TokenStatus::ACTIVE]);

            // 2. Terbitkan Token Lisensi Baru Siap Ditarik (Pull)
            $tokenKey = LicenseToken::generateTokenKey($package?->getTokenPrefix() ?? 'WDEV-PRO-');
            LicenseToken::create([
                'subscription_id' => $subscription->id,
                'tenant_id' => $tenant->id,
                'token_key' => $tokenKey,
                'client_note' => $request->input('client_note') ?? 'Token Baru Generator Lisensi',
                'server_secret' => LicenseToken::generateServerSecret(),
                'status' => TokenStatus::AVAILABLE,
            ]);

            AuditLog::create([
                'action' => 'license_generated',
                'tenant_id' => $tenant->id,
                'details' => "Admin memperbarui kedaluwarsa lisensi ke {$expiryDate->format('Y-m-d')} dan membuat token baru: {$tokenKey}",
            ]);

            return redirect()->back()
                ->with('success', "Lisensi berhasil diperbarui! Kedaluwarsa: {$expiryDate->format('d F Y')}. Token Baru: {$tokenKey}");
        });
    }
}
