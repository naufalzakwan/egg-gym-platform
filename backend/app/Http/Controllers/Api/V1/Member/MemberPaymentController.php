<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Member\CheckoutMembershipPaymentRequest;
use App\Models\MembershipPlan;
use App\Models\Transaction;
use App\Services\ActivityLogger;
use App\Services\Payment\MembershipPaymentMethodService;
use App\Services\Payment\MembershipTransactionExpiryService;
use App\Services\Payment\PakasirService;
use App\Services\Payment\PaymentFulfillmentService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberPaymentController extends Controller
{
    /**
     * Create a membership checkout transaction with Pakasir.
     */
    public function checkout(
        CheckoutMembershipPaymentRequest $request,
        PakasirService $pakasirService,
        MembershipPaymentMethodService $paymentMethods
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $validated = $request->validated();

        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $plan = MembershipPlan::query()
            ->where('id', $validated['membership_plan_id'])
            ->availableForPurchase()
            ->first();

        if (! $plan) {
            return response()->json([
                'success' => false,
                'message' => 'Paket membership tidak aktif atau tidak ditemukan.',
            ], 422);
        }

        $paymentMethod = $paymentMethods->resolveActive($validated['payment_method'], $pakasirService);
        if (! $paymentMethod) {
            return response()->json([
                'success' => false,
                'message' => 'Metode pembayaran sedang tidak tersedia.',
                'errors' => ['payment_method' => ['Metode pembayaran sedang tidak tersedia.']],
            ], 422);
        }

        return $this->buildCheckoutResponse(
            $memberProfile->id,
            $plan,
            $paymentMethod->provider_code,
            $pakasirService
        );
    }

    /**
     * Core pembuatan transaksi checkout Pakasir yang DIPAKAI BERSAMA oleh
     * checkout() dan regeneratePayment(). Generate reference baru, panggil
     * Pakasir, simpan transaksi, kembalikan response checkout (QR/VA).
     */
    private function buildCheckoutResponse(
        int $memberProfileId,
        MembershipPlan $plan,
        string $paymentMethod,
        PakasirService $pakasirService
    ): JsonResponse {
        $referenceCode = 'TRX-'.now()->format('YmdHis').'-'.str_pad(
            (string) random_int(1, 9999),
            4,
            '0',
            STR_PAD_LEFT
        );

        $providerResult = $pakasirService->createTransaction(
            $paymentMethod,
            $referenceCode,
            (float) $plan->price
        );

        if (! $providerResult['success']) {
            return response()->json([
                'success' => false,
                'message' => $providerResult['message'],
                'errors' => isset($providerResult['provider_response'])
                    ? ['provider' => $providerResult['provider_response']]
                    : null,
            ], $providerResult['status_code'] ?? 422);
        }

        $payment = $providerResult['payment'];

        $transaction = Transaction::create([
            'member_profile_id' => $memberProfileId,
            'membership_plan_id' => $plan->id,
            'reference_code' => $referenceCode,
            'title' => 'Checkout '.$plan->name,
            'payment_method' => $providerResult['provider_method'],
            'amount' => $plan->price,
            'status' => 'pending',
            'paid_at' => null,
            'provider_reference' => $payment['order_id'] ?? $referenceCode,
            'provider_name' => 'pakasir',
            'payment_number' => $payment['payment_number'] ?? null,
            'fee' => $payment['fee'] ?? null,
            'total_payment' => $payment['total_payment'] ?? null,
            // Pakasir mengirim ISO-8601 UTC (`...Z`). Kolom DATETIME MySQL tidak
            // menyimpan offset, jadi ubah dulu ke timezone aplikasi agar instant
            // yang tersimpan tidak bergeser tujuh jam ke masa lalu.
            'expired_at' => isset($payment['expired_at'])
                ? CarbonImmutable::parse($payment['expired_at'])
                    ->setTimezone((string) config('app.timezone'))
                : null,
            'provider_payload' => $providerResult['provider_response'] ?? null,
        ]);
        $transaction->load(['memberProfile.user', 'membershipPlan']);
        ActivityLogger::log(
            action: 'transaction_created',
            model: $transaction,
            newData: [
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
                'source' => 'Aplikasi Member',
            ],
            description: "Transaksi membership dibuat: {$transaction->reference_code}",
        );

        $isQris = $providerResult['provider_method'] === 'qris';

        return response()->json([
            'success' => true,
            'message' => 'Checkout Pakasir berhasil dibuat.',
            'data' => [
                'transaction' => [
                    'id' => $transaction->id,
                    'reference_code' => $transaction->reference_code,
                    'payment_method' => $transaction->payment_method,
                    'amount' => (float) $transaction->amount,
                    'fee' => $transaction->fee !== null ? (float) $transaction->fee : null,
                    'total_payment' => $transaction->total_payment !== null
                        ? (float) $transaction->total_payment
                        : null,
                    'status' => $transaction->status,
                ],
                'checkout' => [
                    'provider_name' => 'pakasir',
                    'provider_method' => $providerResult['provider_method'],
                    'payment_code' => $transaction->payment_number,
                    'qr_string' => $isQris ? $transaction->payment_number : null,
                    'expired_at' => $transaction->expired_at?->toIso8601String(),
                    'payment_url' => null,
                ],
            ],
            'meta' => null,
        ], 201);
    }

    /**
     * Regenerate pembayaran untuk transaksi PENDING yang sudah EXPIRED.
     *
     * Anti-duplikasi: transaksi pending lama ditandai 'expired' LEBIH DULU
     * (via MembershipTransactionExpiryService yang sudah ada) sebelum
     * transaksi baru dibuat, supaya tidak ada 2 pending menumpuk untuk paket
     * yang sama. Hanya boleh untuk transaksi yang MEMANG sudah expired
     * (dicek server-side) — kalau belum expired, Flutter cukup reuse QR lama.
     */
    public function regeneratePayment(
        Request $request,
        string $referenceCode,
        PakasirService $pakasirService,
        MembershipTransactionExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $transaction = Transaction::query()
            ->with('membershipPlan')
            ->where('reference_code', $referenceCode)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $transaction) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        if ($transaction->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Hanya transaksi menunggu pembayaran yang bisa dibuat ulang.',
            ], 422);
        }

        // Server-side expiry check (bukan dari device). Kalau belum expired,
        // tolak: Flutter seharusnya reuse QR lama, bukan buat baru.
        if (! $expiryService->shouldExpire($transaction)) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi masih berlaku. Lanjutkan pembayaran dengan QR yang ada.',
            ], 422);
        }

        $plan = $transaction->membershipPlan;

        if (! $plan || ! $plan->isAvailableForPurchase()) {
            return response()->json([
                'success' => false,
                'message' => 'Paket tidak lagi tersedia. Silakan pilih paket dari daftar.',
            ], 422);
        }

        // Tandai transaksi lama EXPIRED dulu (anti-duplikasi), baru buat baru.
        $expiryService->ensureNotExpired($transaction);

        return $this->buildCheckoutResponse(
            $memberProfile->id,
            $plan,
            $transaction->payment_method,
            $pakasirService
        );
    }

    /**
     * Batalkan transaksi PENDING atas permintaan user sendiri.
     *
     * Status diubah jadi 'cancelled' (BUKAN dihapus) supaya tetap tercatat di
     * riwayat transaksi, dan BEDA dari 'expired' (kelewat waktu otomatis).
     * Hanya boleh untuk transaksi milik member yang login & masih 'pending'.
     * TIDAK menyentuh webhook/fulfillment/expired-check: status cancelled tidak
     * lagi lolos guard `status === 'pending'` di logic mana pun.
     */
    public function cancelPayment(
        Request $request,
        string $referenceCode
    ): JsonResponse {
        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        $transaction = Transaction::query()
            ->where('reference_code', $referenceCode)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $transaction) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        // Hanya transaksi menunggu pembayaran yang bisa dibatalkan user.
        // completed/expired/cancelled tidak bisa dibatalkan lagi.
        if ($transaction->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Hanya transaksi menunggu pembayaran yang bisa dibatalkan.',
            ], 422);
        }

        $oldStatus = $transaction->status;
        $transaction->update(['status' => 'cancelled']);
        ActivityLogger::log(
            action: 'transaction_status_changed',
            model: $transaction,
            oldData: ['status' => $oldStatus, 'reference_code' => $transaction->reference_code],
            newData: ['status' => 'cancelled', 'reference_code' => $transaction->reference_code, 'source' => 'Aplikasi Member'],
            description: "Transaksi membership dibatalkan: {$transaction->reference_code}",
        );

        return response()->json([
            'success' => true,
            'message' => 'Pesanan berhasil dibatalkan.',
            'data' => [
                'reference_code' => $transaction->reference_code,
                'status' => $transaction->status,
            ],
            'meta' => null,
        ]);
    }

    /**
     * [SANDBOX/DEV ONLY] Simulasikan pembayaran berhasil untuk testing.
     *
     * Memakai fulfillment yang SAMA dengan webhook asli
     * (PaymentFulfillmentService::fulfill) TANPA verifikasi provider Pakasir.
     * WAJIB hanya aktif di environment non-production; di production endpoint
     * mengembalikan 403 (tidak melakukan apa pun). Idempotent: transaksi yang
     * sudah completed tidak diproses ulang (guard di service).
     */
    public function simulateSuccess(
        Request $request,
        string $referenceCode,
        PaymentFulfillmentService $fulfillmentService
    ): JsonResponse {
        // Guard environment: HANYA sandbox/development. Production -> 403.
        if (app()->environment('production')) {
            return response()->json([
                'success' => false,
                'message' => 'Endpoint simulasi tidak tersedia di production.',
            ], 403);
        }

        $user = $request->user()->load('memberProfile');
        $memberProfile = $user->memberProfile;

        if (! $memberProfile) {
            return response()->json([
                'success' => false,
                'message' => 'Profil member belum tersedia.',
            ], 422);
        }

        // Scoped ke member yang login: hanya boleh mensimulasikan transaksi milik
        // sendiri, tidak bisa menyentuh transaksi member lain.
        $transaction = Transaction::query()
            ->with(['memberProfile.user', 'membershipPlan'])
            ->where('reference_code', $referenceCode)
            ->where('member_profile_id', $memberProfile->id)
            ->first();

        if (! $transaction) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        // Fulfillment bersama (durasi membership dari data paket, bukan hardcode).
        // Sudah completed -> fulfill() mengembalikan false (idempotent skip).
        $processed = $fulfillmentService->fulfill($transaction, now(), [
            'provider_name' => $transaction->provider_name ?? 'pakasir',
        ]);

        return response()->json([
            'success' => true,
            'message' => $processed
                ? 'Simulasi pembayaran berhasil diproses.'
                : 'Transaksi sudah lunas sebelumnya (tidak diproses ulang).',
            'data' => [
                'transaction_id' => $transaction->id,
                'reference_code' => $transaction->reference_code,
                'status' => $transaction->status,
            ],
            'meta' => null,
        ]);
    }
}
