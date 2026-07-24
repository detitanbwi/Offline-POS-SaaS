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

    public function show(string $id)
    {
        $invoice = $this->invoiceRepository->findByIdWithRelations($id);

        return view('admin.invoices.show', compact('invoice'));
    }

    public function uploadPaymentProof(UploadPaymentProofRequest $request, string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        try {
            $this->invoiceService->markAsPaid(
                $invoice,
                'bank_transfer',
                $request->file('payment_proof')
            );

            return redirect()->back()
                ->with('success', "Bukti transfer untuk invoice {$invoice->invoice_number} berhasil diunggah dan status telah berubah menjadi LUNAS!");
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

    public function downloadPdf(string $id)
    {
        $invoice = $this->invoiceRepository->findByIdOrFail($id);

        return $this->pdfService->download($invoice);
    }
}
