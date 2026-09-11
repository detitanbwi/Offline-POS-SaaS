<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Tenant;
use Illuminate\Http\Request;

class TrashController extends Controller
{
    public function index(Request $request)
    {
        $tab = $request->input('tab', 'tenants');
        $search = trim($request->input('search', ''));

        // Query Trashed Tenants
        $tenantQuery = Tenant::onlyTrashed()->latest('deleted_at');
        if ($search !== '' && $tab === 'tenants') {
            $tenantQuery->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('owner_name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('store_name', 'like', "%{$search}%");
            });
        }
        $trashedTenants = $tenantQuery->paginate(15, ['*'], 'tenants_page')->withQueryString();

        // Query Trashed Invoices
        $invoiceQuery = Invoice::onlyTrashed()->with('tenant')->latest('deleted_at');
        if ($search !== '' && $tab === 'invoices') {
            $invoiceQuery->where(function ($q) use ($search) {
                $q->where('invoice_number', 'like', "%{$search}%")
                  ->orWhereHas('tenant', function ($tq) use ($search) {
                      $tq->where('name', 'like', "%{$search}%")
                         ->orWhere('store_name', 'like', "%{$search}%");
                  });
            });
        }
        $trashedInvoices = $invoiceQuery->paginate(15, ['*'], 'invoices_page')->withQueryString();

        $tenantCount = Tenant::onlyTrashed()->count();
        $invoiceCount = Invoice::onlyTrashed()->count();

        return view('admin.trash.index', compact(
            'trashedTenants',
            'trashedInvoices',
            'tenantCount',
            'invoiceCount',
            'tab',
            'search'
        ));
    }
}
