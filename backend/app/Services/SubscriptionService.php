<?php

namespace App\Services;

use App\Enums\SubscriptionStatus;
use App\Enums\TokenStatus;
use App\Models\InvoiceItem;
use App\Models\Subscription;
use App\Repositories\SubscriptionRepository;
use Carbon\Carbon;

class SubscriptionService
{
    public function __construct(
        protected SubscriptionRepository $subscriptionRepository,
    ) {}

    /**
     * Buat Subscription dari InvoiceItem setelah pembayaran berhasil.
     */
    public function createFromInvoiceItem(InvoiceItem $item, string $tenantId): Subscription
    {
        $startDate = Carbon::today();
        $expiryDate = Carbon::today()->addDays($item->duration_days);

        return Subscription::create([
            'tenant_id' => $tenantId,
            'invoice_item_id' => $item->id,
            'package_id' => $item->package_id,
            'package_name' => $item->package_name,
            'status' => SubscriptionStatus::ACTIVE,
            'start_date' => $startDate,
            'expiry_date' => $expiryDate,
        ]);
    }

    /**
     * Cek dan expire subscription yang sudah melewati tanggal expiry.
     * Dijalankan oleh scheduled command.
     */
    public function checkAndExpireSubscriptions(): int
    {
        $expiredSubscriptions = $this->subscriptionRepository->getExpiredButActive();
        $count = 0;

        foreach ($expiredSubscriptions as $subscription) {
            $subscription->update(['status' => SubscriptionStatus::EXPIRED]);

            // Expire semua token yang terkait
            $subscription->licenseTokens()
                ->whereIn('status', [TokenStatus::AVAILABLE, TokenStatus::ACTIVE])
                ->update(['status' => TokenStatus::EXPIRED]);

            $count++;
        }

        return $count;
    }
}
