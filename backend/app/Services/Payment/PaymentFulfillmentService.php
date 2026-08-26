<?php

namespace App\Services\Payment;

use App\Models\MemberMembership;
use App\Models\Transaction;
use App\Services\ActivityLogger;
use App\Services\Notification\NotificationAutomationService;
use App\Services\Notification\UserNotificationService;
use Carbon\Carbon;

/**
 * Logic fulfillment pembayaran membership yang DIPAKAI BERSAMA oleh:
 *  - webhook Pakasir asli (PakasirWebhookController), dan
 *  - endpoint simulasi sandbox (MemberPaymentController::simulateSuccess).
 *
 * Isinya: tandai transaksi completed + paid_at, buat/perpanjang MemberMembership
 * sesuai durasi paket (billing_period), lalu kirim notifikasi. Durasi diambil
 * dari data paket (tidak hardcode).
 *
 * IDEMPOTEN: bila transaksi sudah 'completed', fulfill() langsung berhenti dan
 * TIDAK menambah membership lagi (mencegah dobel hari).
 */
class PaymentFulfillmentService
{
    public function __construct(
        private readonly UserNotificationService $userNotificationService,
        private readonly NotificationAutomationService $notificationAutomation,
    ) {}

    /**
     * Jalankan fulfillment. Mengembalikan true bila baru saja diproses, atau
     * false bila transaksi sudah completed sebelumnya (idempotent skip).
     *
     * @param  array<string, mixed>  $providerOverrides  Field provider opsional
     *                                                   (payment_method, provider_reference, provider_name, provider_payload)
     *                                                   yang diisi webhook asli; simulasi boleh mengosongkan/menyetel minimal.
     */
    public function fulfill(
        Transaction $transaction,
        Carbon $completedAt,
        array $providerOverrides = []
    ): bool {
        // Guard idempotent: sudah diproses -> jangan tambah membership dua kali.
        if ($transaction->status === 'completed') {
            return false;
        }

        $oldTransaction = $this->transactionAuditData($transaction);
        $transaction->update(array_merge([
            'status' => 'completed',
            'paid_at' => $completedAt,
        ], $providerOverrides));

        if ($transaction->membershipPlan) {
            $membershipStartDate = $this->resolveMembershipStartDate(
                $transaction->member_profile_id,
                $completedAt
            );

            $membership = MemberMembership::create([
                'member_profile_id' => $transaction->member_profile_id,
                'membership_plan_id' => $transaction->membership_plan_id,
                'start_date' => $membershipStartDate->toDateString(),
                'end_date' => $this->calculateMembershipEndDate(
                    $membershipStartDate,
                    (string) $transaction->membershipPlan->billing_period
                )->toDateString(),
                'status' => 'active',
                'payment_status' => 'paid',
            ]);
            $membership->load(['memberProfile.user', 'membershipPlan']);
            ActivityLogger::log(
                action: $membershipStartDate->greaterThan($completedAt->copy()->startOfDay())
                    ? 'membership_renewed'
                    : 'membership_created',
                model: $membership,
                newData: $this->membershipAuditData($membership),
                description: ($membershipStartDate->greaterThan($completedAt->copy()->startOfDay())
                    ? 'Membership diperpanjang'
                    : 'Membership diaktifkan').': '.($membership->memberProfile?->user?->name ?? "Member #{$membership->member_profile_id}"),
            );
        }

        $transaction->refresh()->load(['memberProfile.user', 'membershipPlan']);
        $isPakasirWebhook = ($providerOverrides['provider_name'] ?? null) === 'pakasir';
        ActivityLogger::log(
            action: $isPakasirWebhook ? 'pakasir_webhook_updated' : 'transaction_payment_completed',
            model: $transaction,
            oldData: $oldTransaction,
            newData: $this->transactionAuditData($transaction) + [
                'source' => $isPakasirWebhook
                    ? 'Webhook Pakasir'
                    : 'Sistem Pembayaran',
            ],
            description: ($isPakasirWebhook ? 'Webhook Pakasir memperbarui pembayaran membership: ' : 'Pembayaran membership berhasil: ')
                .$transaction->reference_code,
        );

        $memberUser = $transaction->memberProfile?->user;

        if ($memberUser) {
            $this->userNotificationService->notify(
                $memberUser,
                'Pembayaran Membership Berhasil',
                'Pembayaran untuk '.($transaction->membershipPlan?->name ?? 'membership kamu')
                    .' sudah berhasil diverifikasi.',
                'payment',
                'push',
                true,
                [
                    'transaction_id' => (string) $transaction->id,
                    'reference_code' => $transaction->reference_code,
                    'status' => 'completed',
                    'target' => 'membership',
                ],
                "transaction:{$transaction->id}:membership_completed:member"
            );
        }
        $this->notificationAutomation->notifyAdmins(
            'Pembayaran membership berhasil',
            'Ada pembayaran membership baru yang berhasil.',
            'payment',
            [
                'transaction_id' => (string) $transaction->id,
                'member_name' => $transaction->memberProfile?->user?->name,
                'plan_name' => $transaction->membershipPlan?->name,
                'amount' => (string) $transaction->amount,
                'payment_method' => $transaction->payment_method,
                'target' => 'payments_admin',
            ],
            "transaction:{$transaction->id}:membership_completed:admin"
        );

        return true;
    }

    /**
     * Tentukan tanggal mulai membership. Bila member masih punya membership
     * berbayar yang aktif (end_date >= hari fulfillment), membership baru
     * menyambung sehari setelahnya; jika tidak, mulai dari tanggal fulfillment.
     */
    private function resolveMembershipStartDate(
        int $memberProfileId,
        Carbon $completedAt
    ): Carbon {
        $latestPaidMembership = MemberMembership::query()
            ->where('member_profile_id', $memberProfileId)
            ->where('payment_status', 'paid')
            ->whereNotNull('end_date')
            ->orderByDesc('end_date')
            ->first();

        if (
            $latestPaidMembership?->end_date &&
            $latestPaidMembership->end_date->greaterThanOrEqualTo($completedAt->copy()->startOfDay())
        ) {
            return $latestPaidMembership->end_date->copy()->addDay()->startOfDay();
        }

        return $completedAt->copy()->startOfDay();
    }

    private function calculateMembershipEndDate(
        Carbon $startDate,
        string $billingPeriod
    ): Carbon {
        return match ($billingPeriod) {
            'yearly' => $startDate->copy()->addYear()->subDay(),
            default => $startDate->copy()->addMonth()->subDay(),
        };
    }

    private function transactionAuditData(Transaction $transaction): array
    {
        return [
            'reference_code' => $transaction->reference_code,
            'member_profile_id' => $transaction->member_profile_id,
            'member_name' => $transaction->memberProfile?->user?->name,
            'membership_plan_id' => $transaction->membership_plan_id,
            'membership_plan_name' => $transaction->membershipPlan?->name,
            'amount' => $transaction->amount,
            'fee' => $transaction->fee,
            'total_payment' => $transaction->total_payment,
            'payment_method' => $transaction->payment_method,
            'status' => $transaction->status,
            'paid_at' => $transaction->paid_at?->toIso8601String(),
        ];
    }

    private function membershipAuditData(MemberMembership $membership): array
    {
        return [
            'member_profile_id' => $membership->member_profile_id,
            'member_name' => $membership->memberProfile?->user?->name,
            'membership_plan_id' => $membership->membership_plan_id,
            'membership_plan_name' => $membership->membershipPlan?->name,
            'start_date' => $membership->start_date?->toDateString(),
            'end_date' => $membership->end_date?->toDateString(),
            'status' => $membership->status,
            'payment_status' => $membership->payment_status,
            'source' => 'Sistem Pembayaran',
        ];
    }
}
