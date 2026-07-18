<?php

namespace App\Services;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use Barryvdh\DomPDF\Facade\Pdf;

class InvoicePdfService
{
    /**
     * Generate PDF untuk invoice.
     * Template berbeda untuk PAID dan UNPAID.
     */
    public function generate(Invoice $invoice): \Barryvdh\DomPDF\PDF
    {
        $invoice->load(['tenant', 'items.package', 'subscriptions.licenseTokens']);

        $view = $invoice->status === InvoiceStatus::PAID
            ? 'pdf.invoice-paid'
            : 'pdf.invoice-unpaid';

        $data = [
            'invoice' => $invoice,
            'tenant' => $invoice->tenant,
            'items' => $invoice->items,
            'tokens' => $invoice->status === InvoiceStatus::PAID
                ? $invoice->subscriptions->flatMap->licenseTokens
                : collect(),
        ];

        return Pdf::loadView($view, $data)
            ->setPaper('a4', 'portrait')
            ->setOption('defaultFont', 'sans-serif')
            ->setOption('isHtml5ParserEnabled', true)
            ->setOption('isRemoteEnabled', true);
    }

    /**
     * Download PDF.
     */
    public function download(Invoice $invoice)
    {
        $filename = "invoice-{$invoice->invoice_number}.pdf";

        return $this->generate($invoice)->download($filename);
    }

    /**
     * Stream PDF (preview di browser).
     */
    public function stream(Invoice $invoice)
    {
        $filename = "invoice-{$invoice->invoice_number}.pdf";

        return $this->generate($invoice)->stream($filename);
    }
}
