<?php

namespace App\Console\Commands;

use App\Models\GymOperationHour;
use App\Models\TrainingProgramSession;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

class ResetMemberReadyAfterClosing extends Command
{
    protected $signature = 'sessions:reset-member-ready';

    protected $description = 'Reset persetujuan member (member_ready) ke "Start Session" setelah jam operasional gym tutup, atau bila kesiapan sudah stale dari hari sebelumnya.';

    public function handle(): int
    {
        $now = now();
        $gymClosedNow = $this->isGymClosedNow($now);

        $sessions = TrainingProgramSession::query()
            ->where('status', 'active')
            ->where('member_ready', true)
            ->get();

        $resetCount = 0;

        foreach ($sessions as $session) {
            $readyAt = $session->member_ready_at;

            // Kesiapan dikunci ulang (member_ready = false) bila:
            // - ditandai pada hari yang berbeda dari hari ini (stale, member
            //   harus konfirmasi ulang di hari pelaksanaan), ATAU
            // - gym sudah tutup untuk hari ini (sesi tidak jadi dilaksanakan).
            $staleFromPreviousDay = $readyAt === null
                || $readyAt->toDateString() !== $now->toDateString();

            if (! $staleFromPreviousDay && ! $gymClosedNow) {
                continue; // masih hari yang sama & gym masih buka → pertahankan
            }

            // Mengunci sesi murni gembok izin centang trainer — progres exercise
            // yang sudah tercentang TETAP tersimpan (hanya member_ready di-flip).
            // Jadi lock tetap berlaku berapapun progress-nya.
            $session->update([
                'member_ready' => false,
                'member_ready_at' => null,
            ]);

            $resetCount++;
        }

        $this->info("Reset {$resetCount} member-ready session(s).");

        return self::SUCCESS;
    }

    /**
     * Apakah gym sedang tutup pada waktu $now, berdasarkan jam operasional
     * harian yang tersimpan (GymOperationHour).
     */
    private function isGymClosedNow(Carbon $now): bool
    {
        $dayName = $now->format('l'); // Monday, Tuesday, ...

        $hour = GymOperationHour::query()
            ->where('day_name', $dayName)
            ->first();

        // Tidak ada data / hari libur / jam tidak lengkap → anggap tutup.
        if (! $hour || $hour->is_closed || ! $hour->open_time || ! $hour->close_time) {
            return true;
        }

        $currentTime = $now->format('H:i:s');
        $open = substr((string) $hour->open_time, 0, 8);
        $close = substr((string) $hour->close_time, 0, 8);

        // Di luar rentang [open, close) → tutup.
        return $currentTime < $open || $currentTime >= $close;
    }
}
