<?php

namespace App\Http\Controllers;

use App\Enums\InvoiceStatus;
use App\Http\Requests\CreateInvoiceRequest;
use App\Http\Requests\MarkInvoicePaidRequest;
use App\Repositories\InvoiceRepository;
use App\Repositories\PackageRepository;
use App\Repositories\TenantRepository;
use App\Services\InvoicePdfService;
use App\Services\InvoiceService;

use App\Http\Requests\UploadPaymentProofRequest;
use Illuminate\Http\Request;

class AdminInvoiceController extends Controller
{
    public function __construct(
        protected InvoiceRepository $invoiceRepository,
        protected InvoiceService $invoiceService,
        protected InvoicePdfService $pdfService,
        protected TenantRepository $tenantRepository,
        protected PackageRepository $packageRepository,
    ) {}

    public function index()
    {
        $invoices = $this->invoiceRepository->paginate(request()->only(['search', 'status']));
        $statuses = InvoiceStatus::cases();

        return view('admin.invoices.index', compact('invoices', 'statuses'));
    }

    public function create()
    {
        $tenants = $this->tenantRepository->getActive();
        $packages = $this->packageRepository->getActive();

        return view('admin.invoices.create', compact('tenants', 'packages'));
    }

    public function store(CreateInvoiceRequest $request)
    {
        $invoice = $this->invoiceService->createInvoice(
            $request->tenant_id,
            $request->items,
            $request->notes
        );

        return redirect()->route('admin.invoices.show', $invoice)
            ->with('success', "Invoice {$invoice->invoice_number} berhasil dibuat!");
    }

    public function show(Request $request, string $id)
    {
        $invoice = $this->invoiceRepository->findByIdWithRelations($id);

        $previousUrl = url()->previous();
        $currentUrl = $request->fullUrl();

        // 1. Explicit return_to query parameter takes highest priority
        if ($request->filled('return_to')) {
            $backUrl = $request->query('return_to');
            session(['invoice_back_url_' . $id => $backUrl]);
        }
        // 2. If redirected from form action or page reload, preserve the stored backUrl
        elseif (session()->has('invoice_back_url_' . $id) && ($previousUrl === $currentUrl || str_contains($previousUrl, route('admin.invoices.show', $id, false)))) {
            $backUrl = session('invoice_back_url_' . $id);
        }
        // 3. If previous URL is valid, not current URL, and not an action on this invoice
        elseif (!empty($previousUrl) && $previousUrl !== $currentUrl && !str_contains($previousUrl, route('admin.invoices.show', $id, false))) {
            $backUrl = $previousUrl;
            session(['invoice_back_url_' . $id => $backUrl]);
        }
        // 4. Default fallback to invoice list
        else {
            $backUrl = route('admin.invoices.index');
        }

        return view('admin.invoices.show', compact('invoice', 'backUrl'));
    }

    public function uploadPaymentProof(UploadPaymentProofRequest $request, string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        try {
            $this->invoiceService->uploadPaymentProof(
                $invoice,
                $request->file('payment_proof')
            );

            return redirect()->back()
                ->with('success', "Bukti transfer untuk invoice {$invoice->invoice_number} berhasil diunggah!");
        } catch (\LogicException $e) {
            return redirect()->back()
                ->with('error', $e->getMessage());
        }
    }

    public function markAsPaid(MarkInvoicePaidRequest $request, string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        try {
            $this->invoiceService->markAsPaid(
                $invoice,
                $request->payment_method,
                $request->file('payment_proof')
            );

            return redirect()->back()
                ->with('success', "Pembayaran invoice {$invoice->invoice_number} berhasil disetujui (Approved) dan lisensi telah diterbitkan!");
        } catch (\LogicException $e) {
            return redirect()->back()
                ->with('error', $e->getMessage());
        }
    }

    public function cancel(string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        try {
            $this->invoiceService->cancelInvoice($invoice);

            return redirect()->back()
                ->with('success', "Invoice {$invoice->invoice_number} berhasil dibatalkan!");
        } catch (\LogicException $e) {
            return redirect()->back()
                ->with('error', $e->getMessage());
        }
    }

    public function destroy(string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);
        $invoiceNumber = $invoice->invoice_number;
        $this->invoiceRepository->delete($invoice);

        \App\Models\AuditLog::create([
            'action' => 'invoice_deleted',
            'tenant_id' => $invoice->tenant_id,
            'details' => "Invoice {$invoiceNumber} dihapus (Soft Delete ke tempat sampah).",
        ]);

        return redirect()->route('admin.invoices.index')
            ->with('success', "Invoice {$invoiceNumber} berhasil dihapus (tersimpan di tempat sampah)!");
    }

    public function restore(string $id)
    {
        $invoice = $this->invoiceRepository->restore($id);

        \App\Models\AuditLog::create([
            'action' => 'invoice_restored',
            'tenant_id' => $invoice->tenant_id,
            'details' => "Invoice {$invoice->invoice_number} berhasil dipulihkan dari tempat sampah.",
        ]);

        return redirect()->back()
            ->with('success', "Invoice {$invoice->invoice_number} berhasil dipulihkan (Restore)!");
    }

    public function downloadPdf(string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        return $this->pdfService->download($invoice);
    }

    public function report(\Illuminate\Http\Request $request)
    {
        $fromDate = $request->input('from_date', now()->startOfMonth()->toDateString());
        $toDate = $request->input('to_date', now()->toDateString());
        $status = $request->input('status');
        $tenantId = $request->input('tenant_id');

        $query = \App\Models\Invoice::with(['tenant', 'items'])
            ->whereDate('created_at', '>=', $fromDate)
            ->whereDate('created_at', '<=', $toDate);

        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        if ($tenantId) {
            $query->where('tenant_id', $tenantId);
        }

        $invoices = (clone $query)->latest()->paginate(25)->withQueryString();
        
        // Aggregations on all matched records (unpaginated)
        $allRecords = (clone $query)->get();
        $totalRevenue = $allRecords->where('status', \App\Enums\InvoiceStatus::PAID)->sum('total_amount');
        $totalInvoiced = $allRecords->sum('total_amount');
        $countPaid = $allRecords->where('status', \App\Enums\InvoiceStatus::PAID)->count();
        $countTotal = $allRecords->count();

        $tenants = $this->tenantRepository->getActive();
        $statuses = \App\Enums\InvoiceStatus::cases();

        return view('admin.invoices.report', compact(
            'invoices',
            'fromDate',
            'toDate',
            'status',
            'tenantId',
            'totalRevenue',
            'totalInvoiced',
            'countPaid',
            'countTotal',
            'tenants',
            'statuses'
        ));
    }

    public function reportPdf(\Illuminate\Http\Request $request)
    {
        $fromDate = $request->input('from_date', now()->startOfMonth()->toDateString());
        $toDate = $request->input('to_date', now()->toDateString());
        $status = $request->input('status');
        $tenantId = $request->input('tenant_id');

        $query = \App\Models\Invoice::with(['tenant', 'items'])
            ->whereDate('created_at', '>=', $fromDate)
            ->whereDate('created_at', '<=', $toDate);

        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        if ($tenantId) {
            $query->where('tenant_id', $tenantId);
        }

        $invoices = $query->latest()->get();
        $totalRevenue = $invoices->where('status', \App\Enums\InvoiceStatus::PAID)->sum('total_amount');
        $totalInvoiced = $invoices->sum('total_amount');
        $countPaid = $invoices->where('status', \App\Enums\InvoiceStatus::PAID)->count();
        $countTotal = $invoices->count();

        $providerSettings = [
            'company_name' => \App\Models\SystemSetting::getVal('company_name', 'Wirodev Digital Architecture'),
            'company_subtitle' => \App\Models\SystemSetting::getVal('company_subtitle', 'Pusat Pengembangan Sistem SaaS'),
            'company_email' => \App\Models\SystemSetting::getVal('company_email', 'billing@wirodev.com'),
            'company_phone' => \App\Models\SystemSetting::getVal('company_phone', ''),
            'company_address' => \App\Models\SystemSetting::getVal('company_address', ''),
        ];

        $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('admin.invoices.report_pdf', compact(
            'invoices',
            'fromDate',
            'toDate',
            'status',
            'totalRevenue',
            'totalInvoiced',
            'countPaid',
            'countTotal',
            'providerSettings'
        ))->setPaper('a4', 'portrait');

        $filename = "laporan-invoice-{$fromDate}-sd-{$toDate}.pdf";
        return $pdf->download($filename);
    }
}
