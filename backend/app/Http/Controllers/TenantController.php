<?php

namespace App\Http\Controllers;

use App\Enums\SubscriptionStatus;
use App\Enums\TenantStatus;
use App\Enums\TokenStatus;
use App\Http\Requests\CreateTenantRequest;
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

        return view('admin.tenants.create', compact('packages'));
    }

    public function store(CreateTenantRequest $request)
    {
        return DB::transaction(function () use ($request) {
            $data = $request->validated();
            $data['status'] = TenantStatus::ACTIVE;

            $tenant = $this->tenantRepository->create($data);

            // 1. Buat User Kredensial Pemilik
            $password = $request->input('password');
            User::create([
                'tenant_id' => $tenant->id,
                'name' => $tenant->owner_name,
                'email' => $tenant->email,
                'password' => $password,
                'is_admin' => false,
            ]);

            // 2. Otomasi Provisioning Invoice, Subscription & Token Lisensi
            $package = Package::findOrFail($request->input('package_id'));
            $invoice = $this->invoiceService->createInvoice($tenant->id, [
                [
                    'package_id' => $package->id,
                    'quantity' => 1,
                    'duration_days' => $package->default_duration_days,
                    'client_note' => 'Initial Auto-Provisioned Subscription',
                ]
            ], 'Otomatis dibuat saat pendaftaran tenant.');

            $invoice = $this->invoiceService->markAsPaid($invoice, 'Auto Provisioning');
            $subscription = $invoice->subscriptions->first();
            $token = $subscription?->licenseTokens->first();
            $tokenKey = $token?->token_key ?? '-';

            AuditLog::create([
                'action' => 'tenant_provisioned',
                'tenant_id' => $tenant->id,
                'details' => "Tenant {$tenant->name} berhasil didaftarkan dengan paket {$package->name} beserta invoice {$invoice->invoice_number}, user {$tenant->email}, dan token lisensi {$tokenKey}",
            ]);

            return redirect()->route('admin.tenants.show', $tenant)
                ->with('success', "Tenant berhasil didaftarkan! Invoice {$invoice->invoice_number} terbuat. User login: {$tenant->email}, Paket: {$package->name}, Token Lisensi: {$tokenKey}");
        });
    }

    public function show(Tenant $tenant)
    {
        $tenant->load(['invoices' => function ($q) {
            $q->latest()->take(5);
        }, 'subscriptions' => function ($q) {
            $q->latest()->take(5);
        }, 'licenseTokens' => function ($q) {
            $q->latest()->take(10);
        }]);

        return view('admin.tenants.show', compact('tenant'));
    }

    public function edit(Tenant $tenant)
    {
        return view('admin.tenants.edit', compact('tenant'));
    }

    public function update(UpdateTenantRequest $request, Tenant $tenant)
    {
        $this->tenantRepository->update($tenant, $request->validated());

        return redirect()->route('admin.tenants.index')
            ->with('success', 'Tenant berhasil diperbarui!');
    }

    public function destroy(Tenant $tenant)
    {
        $this->tenantRepository->delete($tenant);

        return redirect()->route('admin.tenants.index')
            ->with('success', 'Tenant berhasil dihapus!');
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
