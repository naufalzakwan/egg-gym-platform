<?php

namespace App\Console\Commands;

use App\Services\Booking\BookingRescheduleRequestService;
use Illuminate\Console\Command;

class ExpireRescheduleRequests extends Command
{
    protected $signature = 'reschedule-requests:expire';

    protected $description = 'Expire pending reschedule requests and release proposed slot holds.';

    public function handle(BookingRescheduleRequestService $service): int
    {
        $this->info('Expired '.$service->expirePending().' reschedule request(s).');

        return self::SUCCESS;
    }
}
