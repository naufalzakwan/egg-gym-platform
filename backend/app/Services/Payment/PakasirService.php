<?php

namespace App\Services\Payment;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class PakasirService
{
    /**
     * @return array<string, mixed>
     */
    public function createTransaction(
        string $paymentMethod,
        string $orderId,
        float $amount
    ): array {
        if (! $this->isConfigured()) {
            return [
                'success' => false,
                'message' => 'Konfigurasi Pakasir belum lengkap.',
                'status_code' => 422,
            ];
        }

        $providerMethod = $this->normalizeMethod($paymentMethod);

        if (! $providerMethod) {
            return [
                'success' => false,
                'message' => 'Metode pembayaran belum didukung oleh Pakasir.',
                'status_code' => 422,
            ];
        }

        $payload = [
            'project' => config('services.pakasir.project'),
            'order_id' => $orderId,
            'amount' => (int) round($amount),
            'api_key' => config('services.pakasir.api_key'),
        ];

        try {
            $response = Http::baseUrl((string) config('services.pakasir.base_url'))
                ->timeout((int) config('services.pakasir.timeout', 20))
                ->acceptJson()
                ->post('/api/transactioncreate/'.$providerMethod, $payload);

            if (! $response->successful()) {
                Log::warning('Pakasir create transaction failed.', [
                    'status_code' => $response->status(),
                    'response' => $response->json() ?: $response->body(),
                ]);

                return [
                    'success' => false,
                    'message' => 'Pakasir gagal membuat transaksi.',
                    'status_code' => 502,
                    'provider_response' => $response->json() ?: $response->body(),
                ];
            }

            $payment = $response->json('payment');

            if (! is_array($payment)) {
                return [
                    'success' => false,
                    'message' => 'Response Pakasir tidak valid.',
                    'status_code' => 502,
                    'provider_response' => $response->json(),
                ];
            }

            return [
                'success' => true,
                'provider_method' => $providerMethod,
                'payment' => $payment,
                'provider_response' => $response->json(),
            ];
        } catch (Throwable $throwable) {
            Log::warning('Pakasir create transaction exception.', [
                'message' => $throwable->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => 'Koneksi ke Pakasir gagal.',
                'status_code' => 502,
            ];
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function getTransactionDetail(string $orderId, float $amount): array
    {
        if (! $this->isConfigured()) {
            return [
                'success' => false,
                'message' => 'Konfigurasi Pakasir belum lengkap.',
                'status_code' => 422,
            ];
        }

        try {
            $response = Http::baseUrl((string) config('services.pakasir.base_url'))
                ->timeout((int) config('services.pakasir.timeout', 20))
                ->acceptJson()
                ->get('/api/transactiondetail', [
                    'project' => config('services.pakasir.project'),
                    'amount' => (int) round($amount),
                    'order_id' => $orderId,
                    'api_key' => config('services.pakasir.api_key'),
                ]);

            if (! $response->successful()) {
                Log::warning('Pakasir transaction detail failed.', [
                    'status_code' => $response->status(),
                    'response' => $response->json() ?: $response->body(),
                ]);

                return [
                    'success' => false,
                    'message' => 'Pakasir gagal mengambil detail transaksi.',
                    'status_code' => 502,
                    'provider_response' => $response->json() ?: $response->body(),
                ];
            }

            $transaction = $response->json('transaction');

            if (! is_array($transaction)) {
                return [
                    'success' => false,
                    'message' => 'Response detail transaksi Pakasir tidak valid.',
                    'status_code' => 502,
                    'provider_response' => $response->json(),
                ];
            }

            return [
                'success' => true,
                'transaction' => $transaction,
                'provider_response' => $response->json(),
            ];
        } catch (Throwable $throwable) {
            Log::warning('Pakasir transaction detail exception.', [
                'message' => $throwable->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => 'Koneksi ke Pakasir gagal saat cek detail transaksi.',
                'status_code' => 502,
            ];
        }
    }

    public function isConfigured(): bool
    {
        return filled(config('services.pakasir.project'))
            && filled(config('services.pakasir.api_key'));
    }

    public function normalizeMethod(string $paymentMethod): ?string
    {
        return match ($paymentMethod) {
            'qris' => 'qris',
            'virtual_account' => 'bni_va',
            'bni_va' => 'bni_va',
            'bri_va' => 'bri_va',
            'permata_va' => 'permata_va',
            'cimb_niaga_va' => 'cimb_niaga_va',
            'atm_bersama_va' => 'atm_bersama_va',
            'maybank_va' => 'maybank_va',
            'sampoerna_va' => 'sampoerna_va',
            'bnc_va' => 'bnc_va',
            'artha_graha_va' => 'artha_graha_va',
            default => null,
        };
    }
}
