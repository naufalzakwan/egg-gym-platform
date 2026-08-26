<?php

namespace App\Services\Payment;

use App\Models\Transaction;
use App\Services\ActivityLogger;
use App\Services\Notification\NotificationAutomationService;
use App\Services\Notification\UserNotificationService;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;

class MembershipTransactionExpiryService
{
    public const EXPIRY_MINUTES = 30;

    public function __construct(
        private readonly UserNotificationService $notifications,
        private readonly NotificationAutomationService $automation,
    ) {}

    public function ensureNotExpired(Transaction $transaction): Transaction
    {
        if ($this->shouldExpire($transaction)) {
            $oldStatus = $transaction->status;
            $transaction->update([
                'status' => 'expired',
            ]);
            $this->logExpired($transaction, $oldStatus);
            $this->notifyExpired($transaction);
        }

        return $transaction->refresh();
    }

    public function expirePendingTransactions(): int
    {
        $transactions = Transaction::query()
            ->whereNotNull('membership_plan_id')
            ->where('status', 'pending')
            ->whereNotNull('expired_at')
            ->where('expired_at', '<=', now())
            ->get();

        $transactions->each(function (Transaction $transaction) {
            $oldStatus = $transaction->status;
            $transaction->update(['status' => 'expired']);
            $this->logExpired($transaction, $oldStatus);
            $this->notifyExpired($transaction);
        });

        return $transactions->count();
    }

    public function syncCollection(Collection $transactions): Collection
    {
        return $transactions->map(fn (Transaction $transaction) => $this->ensureNotExpired($transaction));
    }

    public function resolveExpiryTimestamp(?CarbonInterface $createdAt = null): CarbonInterface
    {
        return ($createdAt ?? now())->copy()->addMinutes(self::EXPIRY_MINUTES);
    }

    public function shouldExpire(Transaction $transaction): bool
    {
        if (! $transaction->membership_plan_id) {
            return false;
        }

        if ($transaction->status !== 'pending') {
            return false;
        }

        if (! $transaction->expired_at) {
            return false;
        }

        return $transaction->expired_at->lessThanOrEqualTo(now());
    }

    public function canUploadProof(Transaction $transaction): bool
    {
        return false;
    }

    public function remainingSeconds(Transaction $transaction): int
    {
        $transaction = $this->ensureNotExpired($transaction);

        if (! $transaction->expired_at) {
            return 0;
        }

        return max(0, now()->diffInSeconds($transaction->expired_at, false));
    }

    private function logExpired(Transaction $transaction, string $oldStatus): void
    {
        ActivityLogger::log(
            action: 'transaction_status_changed',
            model: $transaction,
            oldData: ['status' => $oldStatus, 'reference_code' => $transaction->reference_code],
            newData: ['status' => 'expired', 'reference_code' => $transaction->reference_code, 'source' => 'Sistem Kedaluwarsa'],
            description: "Transaksi membership kedaluwarsa: {$transaction->reference_code}",
        );
    }

    private function notifyExpired(Transaction $transaction): void
    {
        $transaction->loadMissing(['memberProfile.user', 'membershipPlan']);
        if ($transaction->memberProfile?->user) {
            $this->notifications->notify($transaction->memberProfile->user, 'Pembayaran membership kedaluwarsa', 'Transaksi membership Anda kedaluwarsa sebelum pembayaran selesai.', 'payment', 'push', true, ['transaction_id' => (string) $transaction->id, 'target' => 'membership'], "transaction:{$transaction->id}:expired:member", 'high');
        }
        $this->automation->notifyAdmins('Pembayaran membership gagal', 'Ada transaksi membership yang gagal atau kedaluwarsa.', 'payment', ['transaction_id' => (string) $transaction->id, 'target' => 'payments_admin'], "transaction:{$transaction->id}:expired:admin", 'high');
    }
}
