<?php

namespace App\Console\Commands;

use App\Services\Payment\MembershipTransactionExpiryService;
use Illuminate\Console\Command;

class ExpireMembershipTransactions extends Command
{
    protected $signature = 'membership-transactions:expire';

    protected $description = 'Expire membership transactions after the 30 minute payment window.';

    public function handle(MembershipTransactionExpiryService $expiryService): int
    {
        $expiredCount = $expiryService->expirePendingTransactions();

        $this->info("Expired {$expiredCount} membership transaction(s).");

        return self::SUCCESS;
    }
}
