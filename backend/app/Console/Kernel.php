<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        $schedule->command('trainer-schedules:materialize')
            ->dailyAt('00:05')
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();

        // Reset persetujuan member (member_ready) setelah jam operasional gym
        // tutup atau bila kesiapan sudah stale dari hari sebelumnya.
        $schedule->command('sessions:reset-member-ready')
            ->everyFifteenMinutes()
            ->withoutOverlapping();

        $schedule->command('bookings:expire-pending')
            ->everyMinute()
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();

        $schedule->command('reschedule-requests:expire')
            ->everyMinute()
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();

        $schedule->command('notifications:process-reminders')
            ->everyMinute()
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();

        $schedule->command('notifications:process-reminders --daily')
            ->dailyAt('06:00')
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();

        $schedule->command('membership-transactions:expire')
            ->everyMinute()
            ->timezone('Asia/Jakarta')
            ->withoutOverlapping();
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
