<?php

namespace App\Http\Controllers;

use App\Enums\TenantStatus;
use App\Http\Requests\CreateTenantRequest;
use App\Http\Requests\UpdateTenantRequest;
use App\Models\Tenant;
use App\Repositories\TenantRepository;

class TenantController extends Controller
{
    public function __construct(
        protected TenantRepository $tenantRepository,
    ) {}

    public function index()
    {
        $tenants = $this->tenantRepository->paginate(request()->only(['search', 'status']));
        $statuses = TenantStatus::cases();

        return view('admin.tenants.index', compact('tenants', 'statuses'));
    }

    public function create()
    {
        return view('admin.tenants.create');
    }

    public function store(CreateTenantRequest $request)
    {
        $data = $request->validated();
        $data['status'] = TenantStatus::ACTIVE;

        $this->tenantRepository->create($data);

        return redirect()->route('admin.tenants.index')
            ->with('success', 'Tenant berhasil dibuat!');
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
}
