<?php

namespace App\Console\Commands;

use App\Services\Notification\NotificationAutomationService;
use Illuminate\Console\Command;

class ProcessNotificationReminders extends Command
{
    protected $signature = 'notifications:process-reminders {--daily}';

    protected $description = 'Memproses reminder notifikasi role-based yang idempotent';

    public function handle(NotificationAutomationService $automation): int
    {
        $count = $this->option('daily')
            ? $automation->processDailyReminders()
            : $automation->processMinuteReminders();
        $this->info("{$count} grup reminder diproses.");

        return self::SUCCESS;
    }
}
