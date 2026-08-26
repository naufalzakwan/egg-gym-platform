<?php

namespace App\Console\Commands;

use App\Services\Booking\BookingRequestExpiryService;
use Illuminate\Console\Command;

class ExpirePendingBookings extends Command
{
    protected $signature = 'bookings:expire-pending';

    protected $description = 'Expire overdue booking lifecycle deadlines and release remaining reservations.';

    public function handle(BookingRequestExpiryService $expiryService): int
    {
        $expiredCount = $expiryService->expirePendingBookings();

        $this->info("Expired {$expiredCount} overdue booking(s).");

        return self::SUCCESS;
    }
}
