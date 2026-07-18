<?php

namespace App\Console\Commands;

use App\Services\SubscriptionService;
use Illuminate\Console\Command;

class CheckSubscriptionExpiry extends Command
{
    protected $signature = 'subscription:check-expiry';

    protected $description = 'Cek dan nonaktifkan subscription yang telah melewati tanggal kedaluwarsa';

    public function handle(SubscriptionService $subscriptionService): int
    {
        $this->info('Memulai pengecekan expiry subscription...');

        $expiredCount = $subscriptionService->checkAndExpireSubscriptions();

        $this->info("Pengecekan selesai. {$expiredCount} subscription telah diubah statusnya menjadi EXPIRED.");

        return Command::SUCCESS;
    }
}
