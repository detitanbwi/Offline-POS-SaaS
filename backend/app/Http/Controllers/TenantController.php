<?php

namespace App\Http\Controllers;

use App\Models\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class TenantController extends Controller
{
    public function index(Request $request)
    {
        $query = Tenant::query();

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%$search%")
                  ->orWhere('owner_name', 'like', "%$search%")
                  ->orWhere('email', 'like', "%$search%");
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        $tenants = $query->orderBy('created_at', 'desc')->paginate(10);

        return view('admin.tenants.index', compact('tenants'));
    }

    public function create()
    {
        return view('admin.tenants.create');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'owner_name' => 'required|string|max:255',
            'email' => 'required|email|unique:tenants,email',
            'phone' => 'nullable|string|max:20',
            'store_name' => 'nullable|string|max:255',
            'store_address' => 'nullable|string|max:255',
        ]);

        $data['id'] = (string) Str::uuid();
        $data['status'] = 'active';

        Tenant::create($data);

        return redirect()->route('admin.tenants.index')->with('success', 'Tenant berhasil dibuat!');
    }

    public function show(Tenant $tenant)
    {
        return view('admin.tenants.show', compact('tenant'));
    }

    public function edit(Tenant $tenant)
    {
        return view('admin.tenants.edit', compact('tenant'));
    }

    public function update(Request $request, Tenant $tenant)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'owner_name' => 'required|string|max:255',
            'email' => 'required|email|unique:tenants,email,' . $tenant->id,
            'phone' => 'nullable|string|max:20',
            'store_name' => 'nullable|string|max:255',
            'store_address' => 'nullable|string|max:255',
        ]);

        $tenant->update($data);

        return redirect()->route('admin.tenants.index')->with('success', 'Tenant berhasil diperbarui!');
    }

    public function destroy(Tenant $tenant)
    {
        $tenant->delete();
        return redirect()->route('admin.tenants.index')->with('success', 'Tenant berhasil dihapus!');
    }

    public function suspend(Tenant $tenant)
    {
        $tenant->update(['status' => 'suspended']);
        return redirect()->back()->with('success', 'Tenant berhasil ditangguhkan (suspended)!');
    }

    public function reactivate(Tenant $tenant)
    {
        $tenant->update(['status' => 'active']);
        return redirect()->back()->with('success', 'Tenant berhasil diaktifkan kembali!');
    }
}
