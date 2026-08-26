<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Services\Payment\PakasirService;
use App\Services\Payment\PaymentFulfillmentService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PakasirWebhookController extends Controller
{
    public function handle(
        Request $request,
        PakasirService $pakasirService,
        PaymentFulfillmentService $fulfillmentService
    ): JsonResponse {
        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:1'],
            'order_id' => ['required', 'string'],
            'project' => ['required', 'string'],
            'status' => ['required', 'string'],
            'payment_method' => ['required', 'string'],
            'completed_at' => ['nullable', 'date'],
        ]);

        if ($validated['project'] !== config('services.pakasir.project')) {
            return response()->json([
                'success' => false,
                'message' => 'Project webhook Pakasir tidak cocok.',
            ], 422);
        }

        $transaction = Transaction::query()
            ->with(['memberProfile.user', 'membershipPlan'])
            ->where('reference_code', $validated['order_id'])
            ->first();

        if (! $transaction) {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi tidak ditemukan.',
            ], 404);
        }

        if ((int) round((float) $transaction->amount) !== (int) round((float) $validated['amount'])) {
            return response()->json([
                'success' => false,
                'message' => 'Amount webhook tidak cocok dengan transaksi lokal.',
            ], 422);
        }

        if ($transaction->status === 'completed') {
            return response()->json([
                'success' => true,
                'message' => 'Webhook Pakasir sudah pernah diproses.',
                'data' => [
                    'transaction_id' => $transaction->id,
                    'reference_code' => $transaction->reference_code,
                    'status' => $transaction->status,
                ],
                'meta' => null,
            ]);
        }

        $detailResult = $pakasirService->getTransactionDetail(
            $transaction->reference_code,
            (float) $transaction->amount
        );

        if (! $detailResult['success']) {
            return response()->json([
                'success' => false,
                'message' => $detailResult['message'],
                'errors' => isset($detailResult['provider_response'])
                    ? ['provider' => $detailResult['provider_response']]
                    : null,
            ], $detailResult['status_code'] ?? 502);
        }

        $providerTransaction = $detailResult['transaction'];

        if (
            ($providerTransaction['project'] ?? null) !== config('services.pakasir.project') ||
            ($providerTransaction['order_id'] ?? null) !== $transaction->reference_code ||
            (int) round((float) ($providerTransaction['amount'] ?? 0)) !== (int) round((float) $transaction->amount)
        ) {
            return response()->json([
                'success' => false,
                'message' => 'Verifikasi detail transaksi Pakasir tidak cocok.',
            ], 422);
        }

        if (($providerTransaction['status'] ?? null) !== 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Status transaksi Pakasir belum completed.',
            ], 422);
        }

        $completedAt = ! empty($providerTransaction['completed_at'])
            ? Carbon::parse($providerTransaction['completed_at'])
            : (! empty($validated['completed_at'])
                ? Carbon::parse($validated['completed_at'])
                : now());

        // Fulfillment (update completed + paid_at + membership + notifikasi)
        // dipakai bersama via PaymentFulfillmentService. Field provider dari
        // hasil verifikasi Pakasir tetap dikirim sebagai override.
        $fulfillmentService->fulfill(
            $transaction,
            $completedAt,
            [
                'payment_method' => $providerTransaction['payment_method'] ?? $transaction->payment_method,
                'provider_reference' => $providerTransaction['order_id'] ?? $transaction->provider_reference,
                'provider_name' => 'pakasir',
                'provider_payload' => $detailResult['provider_response'] ?? $transaction->provider_payload,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Webhook Pakasir berhasil diproses.',
            'data' => [
                'transaction_id' => $transaction->id,
                'reference_code' => $transaction->reference_code,
                'status' => 'completed',
            ],
            'meta' => null,
        ]);
    }
}
