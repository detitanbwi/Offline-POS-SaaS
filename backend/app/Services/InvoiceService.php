<?php

namespace App\Services;

use App\Enums\InvoiceStatus;
use App\Enums\TokenStatus;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\LicenseToken;
use App\Models\Package;
use App\Models\Subscription;
use App\Repositories\InvoiceRepository;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class InvoiceService
{
    public function __construct(
        protected InvoiceRepository $invoiceRepository,
        protected SubscriptionService $subscriptionService,
        protected AuditService $auditService,
    ) {}

    /**
     * Buat invoice baru dengan items.
     *
     * @param  array  $items  Format: [['package_id' => '...', 'quantity' => 2, 'duration_days' => 365], ...]
     */
    public function createInvoice(string $tenantId, array $items, ?string $notes = null): Invoice
    {
        return DB::transaction(function () use ($tenantId, $items, $notes) {
            // Buat Invoice
            $invoice = Invoice::create([
                'tenant_id' => $tenantId,
                'invoice_number' => Invoice::generateInvoiceNumber(),
                'status' => InvoiceStatus::UNPAID,
                'subtotal' => 0,
                'tax_amount' => 0,
                'total_amount' => 0,
                'due_date' => now()->addDays(7),
                'notes' => $notes,
            ]);

            $subtotal = 0;

            foreach ($items as $itemData) {
                $package = Package::findOrFail($itemData['package_id']);
                $quantity = $itemData['quantity'] ?? 1;
                $durationDays = $itemData['duration_days'] ?? $package->default_duration_days;
                $unitPrice = $package->price;
                $totalPrice = $unitPrice * $quantity;

                InvoiceItem::create([
                    'invoice_id' => $invoice->id,
                    'package_id' => $package->id,
                    'package_name' => $package->name,
                    'client_note' => $itemData['client_note'] ?? null,
                    'quantity' => $quantity,
                    'duration_days' => $durationDays,
                    'unit_price' => $unitPrice,
                    'total_price' => $totalPrice,
                ]);

                $subtotal += $totalPrice;
            }

            $invoice->update([
                'subtotal' => $subtotal,
                'total_amount' => $subtotal, // Tanpa pajak untuk saat ini
            ]);

            $this->auditService->log(
                'invoice_created',
                $tenantId,
                null,
                null,
                "Invoice {$invoice->invoice_number} dibuat, total: Rp ".number_format($subtotal, 0, ',', '.')
            );

            return $invoice->load('items.package');
        });
    }

    /**
     * Upload bukti transfer pembayaran invoice.
     */
    public function uploadPaymentProof(Invoice $invoice, UploadedFile $file): Invoice
    {
        if ($invoice->status === InvoiceStatus::CANCELLED) {
            throw new \LogicException("Tidak dapat mengunggah bukti transfer untuk invoice yang sudah dibatalkan.");
        }

        // Hapus file bukti lama jika ada
        if ($invoice->payment_proof && Storage::disk('public')->exists($invoice->payment_proof)) {
            Storage::disk('public')->delete($invoice->payment_proof);
        }

        $path = $file->store('payment_proofs', 'public');

        $invoice->update([
            'payment_proof' => $path,
        ]);

        $this->auditService->log(
            'payment_proof_uploaded',
            $invoice->tenant_id,
            null,
            null,
            "Bukti transfer untuk Invoice {$invoice->invoice_number} berhasil diunggah"
        );

        return $invoice;
    }

    /**
     * Tandai invoice sebagai PAID (Approval Pembayaran).
     * Ini akan otomatis membuat Subscription dan Generate Token.
     */
    public function markAsPaid(Invoice $invoice, ?string $paymentMethod = null, ?UploadedFile $proofFile = null): Invoice
    {
        if ($invoice->status !== InvoiceStatus::UNPAID) {
            throw new \LogicException("Invoice {$invoice->invoice_number} tidak dalam status UNPAID.");
        }

        return DB::transaction(function () use ($invoice, $paymentMethod, $proofFile) {
            $proofPath = $invoice->payment_proof;

            if ($proofFile) {
                if ($invoice->payment_proof && Storage::disk('public')->exists($invoice->payment_proof)) {
                    Storage::disk('public')->delete($invoice->payment_proof);
                }
                $proofPath = $proofFile->store('payment_proofs', 'public');
            }

            // Update status invoice
            $invoice->update([
                'status' => InvoiceStatus::PAID,
                'paid_at' => now(),
                'payment_method' => $paymentMethod ?? $invoice->payment_method ?? 'bank_transfer',
                'payment_proof' => $proofPath,
            ]);

            // Load items
            $invoice->load('items.package');

            // Untuk setiap InvoiceItem → buat Subscription → generate Tokens
            foreach ($invoice->items as $item) {
                $subscription = $this->subscriptionService->createFromInvoiceItem($item, $invoice->tenant_id);
                $this->generateTokensForSubscription($subscription, $item);
            }

            $this->auditService->log(
                'invoice_paid',
                $invoice->tenant_id,
                null,
                null,
                "Invoice {$invoice->invoice_number} dibayar via {$paymentMethod}"
            );

            return $invoice->load(['items.package', 'subscriptions.licenseTokens']);
        });
    }

    /**
     * Batalkan invoice.
     */
    public function cancelInvoice(Invoice $invoice): Invoice
    {
        if ($invoice->status === InvoiceStatus::PAID) {
            throw new \LogicException('Invoice yang sudah dibayar tidak dapat dibatalkan.');
        }

        $invoice->update(['status' => InvoiceStatus::CANCELLED]);

        $this->auditService->log(
            'invoice_cancelled',
            $invoice->tenant_id,
            null,
            null,
            "Invoice {$invoice->invoice_number} dibatalkan"
        );

        return $invoice;
    }

    /**
     * Generate token untuk subscription berdasarkan quantity invoice item.
     */
    protected function generateTokensForSubscription(Subscription $subscription, InvoiceItem $item): void
    {
        $package = $item->package;
        $packagePrefix = $package ? $package->getTokenPrefix() : 'GEN';

        for ($i = 0; $i < $item->quantity; $i++) {
            // Pastikan token key unik
            do {
                $tokenKey = LicenseToken::generateTokenKey($packagePrefix);
            } while (LicenseToken::where('token_key', $tokenKey)->exists());

            $note = $item->client_note;
            if ($item->quantity > 1 && $note) {
                $note .= ' #'.($i + 1);
            }

            LicenseToken::create([
                'subscription_id' => $subscription->id,
                'tenant_id' => $subscription->tenant_id,
                'token_key' => $tokenKey,
                'client_note' => $note,
                'server_secret' => LicenseToken::generateServerSecret(),
                'status' => TokenStatus::AVAILABLE,
            ]);
        }

        $this->auditService->log(
            'tokens_generated',
            $subscription->tenant_id,
            null,
            null,
            "{$item->quantity} token di-generate untuk subscription {$subscription->id}, package: {$item->package_name}"
        );
    }
}
