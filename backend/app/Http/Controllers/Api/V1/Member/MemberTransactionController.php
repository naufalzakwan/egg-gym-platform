<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Member\TransactionResource;
use App\Models\Transaction;
use App\Services\Payment\MembershipTransactionExpiryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberTransactionController extends Controller
{
    /**
     * Display the authenticated member transactions.
     */
    public function index(
        Request $request,
        MembershipTransactionExpiryService $expiryService
    ): JsonResponse {
        $user = $request->user();

        // Urut MURNI created_at desc (terbaru -> lama) untuk SEMUA status
        // sekaligus (success/pending/cancelled/expired), TIDAK dikelompokkan
        // per status. Sebelumnya latest('paid_at') menaruh yang sudah dibayar
        // di atas, bikin urutan tidak murni berdasarkan waktu dibuat.
        $transactions = Transaction::query()
            ->with('membershipPlan')
            ->whereNotNull('membership_plan_id')
            ->whereHas('membershipPlan')
            ->whereHas('memberProfile', function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->latest('created_at')
            ->latest('id')
            ->get();

        // Lazy-sync: transaksi PENDING yang sudah lewat expired_at diubah jadi
        // 'expired' saat dibaca (pakai service yang sama dgn cron/expired-check).
        // Ini yang membuat auto-refresh 5 detik di halaman status/QR benar-benar
        // memantulkan status EXPIRED dari backend saat countdown habis, bukan
        // cuma UI. TIDAK menyentuh logic pembuatan transaksi / durasi Pakasir.
        $transactions = $expiryService->syncCollection($transactions);

        return response()->json([
            'success' => true,
            'message' => 'Data transaksi member berhasil diambil.',
            'data' => TransactionResource::collection($transactions),
            'meta' => null,
        ]);
    }
}
