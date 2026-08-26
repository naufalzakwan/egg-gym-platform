<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\MemberMembership;
use App\Models\MembershipPlan;
use App\Models\Transaction;
use App\Services\ActivityLogger;
use App\Services\Admin\MembershipRevenueService;
use App\Services\Admin\MembershipTransactionWorkbookService;
use Carbon\Carbon;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;

class TransactionMonitorController extends Controller
{
    /** Status DB yang dianggap "sukses". */
    private const SUCCESS_STATUSES = ['completed', 'paid'];

    private const PENDING_STATUSES = ['pending', 'waiting', 'waiting_payment'];

    public function __construct(
        private readonly MembershipRevenueService $membershipRevenue,
        private readonly MembershipTransactionWorkbookService $transactionWorkbook,
    ) {}

    public function index(Request $request): View
    {
        $transactions = $this->buildQuery($request)
            ->latest('created_at')
            ->paginate(5)
            ->withQueryString();

        $membershipOptions = MembershipPlan::query()
            ->availableForPurchase()
            ->orderBy('name')
            ->get(['id', 'name']);

        return view('admin.transactions.index', [
            'transactions' => $transactions,
            'search' => $request->query('search', ''),
            'status' => $request->query('status', ''),
            'dateFilter' => $request->query('date', ''),
            'membershipPackageId' => $request->query('membership_package_id', ''),
            'metode' => $request->query('metode', ''),
            'kpi' => $this->buildKpi($request),
            'methodOptions' => Transaction::query()
                ->select('payment_method')->distinct()
                ->whereNotNull('membership_plan_id')
                ->whereNotNull('payment_method')
                ->pluck('payment_method')->filter()->values(),
            'membershipOptions' => $membershipOptions,
        ]);
    }

    /** Export transaksi sesuai filter aktif ke workbook Excel asli. */
    public function exportLedger(Request $request): StreamedResponse
    {
        $rows = $this->buildQuery($request)->latest('created_at')->get();
        $filename = 'laporan-transaksi-membership-'.now()->format('Y-m-d').'.xlsx';
        $workbook = $this->transactionWorkbook->build($rows, $this->exportPeriodLabel($request));

        ActivityLogger::logAction('export_ledger', "Export ledger transaksi ({$rows->count()} baris).");

        return response()->streamDownload(function () use ($workbook) {
            (new Xlsx($workbook))->save('php://output');
            $workbook->disconnectWorksheets();
        }, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Cache-Control' => 'max-age=0, no-cache, no-store, must-revalidate',
        ]);
    }

    private function exportPeriodLabel(Request $request): string
    {
        $now = now(config('app.timezone'));

        return match ($request->query('date', '')) {
            'today' => $now->locale('id')->translatedFormat('d F Y'),
            'week' => $now->copy()->startOfWeek()->locale('id')->translatedFormat('d F Y')
                .' - '.$now->copy()->endOfWeek()->locale('id')->translatedFormat('d F Y'),
            'month' => $now->locale('id')->translatedFormat('F Y'),
            default => 'Semua Tanggal',
        };
    }

    /**
     * Query bersama untuk index & export — menerapkan search + filter
     * tanggal/paket/metode/status yang sama persis.
     */
    private function buildQuery(Request $request)
    {
        $search = trim((string) $request->query('search', ''));
        $status = trim((string) $request->query('status', ''));
        $date = trim((string) $request->query('date', ''));
        $membershipPackageId = trim((string) $request->query('membership_package_id', ''));
        $metode = trim((string) $request->query('metode', ''));

        return Transaction::query()
            ->with(['memberProfile.user', 'membershipPlan'])
            ->whereNotNull('membership_plan_id')
            ->when($search !== '', function ($q) use ($search) {
                $q->where(function ($inner) use ($search) {
                    $inner->where('reference_code', 'like', "%{$search}%")
                        ->orWhere('title', 'like', "%{$search}%")
                        ->orWhere('payment_method', 'like', "%{$search}%")
                        ->orWhere('status', 'like', "%{$search}%")
                        ->orWhere('amount', 'like', "%{$search}%")
                        ->orWhere('total_payment', 'like', "%{$search}%")
                        ->orWhereHas('membershipPlan', fn ($plan) => $plan->where('name', 'like', "%{$search}%"))
                        ->orWhereHas('memberProfile.user', fn ($u) => $u->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%"));
                });
            })
            ->when($status !== '', fn ($q) => $q->where('status', $status))
            ->when(ctype_digit($membershipPackageId), fn ($q) => $q->where('membership_plan_id', (int) $membershipPackageId))
            ->when($metode !== '', fn ($q) => $q->where('payment_method', $metode))
            // Tanggal transaksi mengikuti kolom yang ditampilkan: paid_at untuk
            // transaksi lunas, created_at untuk status yang belum dibayar.
            ->when($date === 'today', fn ($q) => $q->whereBetween(
                DB::raw('COALESCE(paid_at, created_at)'),
                [now()->startOfDay(), now()->endOfDay()]
            ))
            ->when($date === 'week', fn ($q) => $q->whereBetween(
                DB::raw('COALESCE(paid_at, created_at)'),
                [now()->startOfWeek(), now()->endOfWeek()]
            ))
            ->when($date === 'month', fn ($q) => $q->whereBetween(
                DB::raw('COALESCE(paid_at, created_at)'),
                [now()->startOfMonth(), now()->endOfMonth()]
            ));
    }

    /**
     * KPI stat cards (data nyata).
     */
    private function buildKpi(Request $request): array
    {
        $now = now(config('app.timezone'));
        $monthStart = $now->copy()->startOfMonth();
        $monthEnd = $now->copy()->endOfMonth();
        $renewal = $this->buildMembershipRenewalKpi($monthStart, $monthEnd);
        $totalRevenue = $this->membershipRevenue->summarizeSuccessfulQuery(
            $this->buildQuery($request)
        );

        return [
            'revenue_label' => $totalRevenue['successful_count'] > 0 && $totalRevenue['known_count'] === 0
                ? 'Belum tersedia'
                : $this->membershipRevenue->formatRupiah($totalRevenue['net']),
            'revenue_value' => $totalRevenue['net'],
            'revenue_success_count' => $totalRevenue['successful_count'],
            'revenue_caption' => 'Seluruh transaksi Membership sukses',
            'net_known_count' => $totalRevenue['known_count'],
            'net_unknown_count' => $totalRevenue['unknown_count'],
            'successful_member_count' => $totalRevenue['successful_member_count'],
            'successful_member_caption' => $totalRevenue['successful_member_count'] > 0
                ? 'Member unik dengan transaksi sukses'
                : 'Belum ada member sesuai filter',
            'average_transaction_value' => $totalRevenue['average_net'],
            'average_transaction_label' => $this->membershipRevenue->formatRupiah($totalRevenue['average_net']),
            'average_transaction_caption' => $totalRevenue['known_count'] > 0
                ? 'Dari transaksi membership sukses'
                : 'Belum ada transaksi sukses',
            'renewal_rate' => $renewal['rate'],
            'renewal_label' => $renewal['rate'] === null
                ? 'Belum tersedia'
                : number_format($renewal['rate'], 1, ',', '.').'%',
            'renewal_eligible' => $renewal['eligible'],
            'renewal_members' => $renewal['renewed'],
            'period_label' => $monthStart->locale('id')->translatedFormat('F Y'),
        ];
    }

    private function buildMembershipRenewalKpi(Carbon $monthStart, Carbon $monthEnd): array
    {
        $expiredPeriods = MemberMembership::query()
            ->where('payment_status', 'paid')
            ->whereBetween('end_date', [$monthStart->toDateString(), $monthEnd->toDateString()])
            ->orderBy('member_profile_id')
            ->orderBy('end_date')
            ->get(['id', 'member_profile_id', 'start_date', 'end_date'])
            ->groupBy('member_profile_id')
            ->map(fn ($rows) => $rows->last());

        if ($expiredPeriods->isEmpty()) {
            return ['rate' => null, 'eligible' => 0, 'renewed' => 0];
        }

        $renewed = $expiredPeriods->filter(function (MemberMembership $expired): bool {
            return MemberMembership::query()
                ->where('member_profile_id', $expired->member_profile_id)
                ->where('payment_status', 'paid')
                ->where('id', '!=', $expired->id)
                ->whereDate('start_date', '>', $expired->start_date->toDateString())
                ->whereDate('start_date', '<=', $expired->end_date->copy()->addDay()->toDateString())
                ->exists();
        })->count();

        return [
            'rate' => round($renewed / $expiredPeriods->count() * 100, 1),
            'eligible' => $expiredPeriods->count(),
            'renewed' => $renewed,
        ];
    }

    private function methodLabel(?string $method): string
    {
        return match ($method) {
            'qris' => 'QRIS',
            'virtual_account' => 'Virtual Account',
            'bni_va' => 'VA BNI',
            'bri_va' => 'VA BRI',
            'bca_va' => 'VA BCA',
            'mandiri_va' => 'VA Mandiri',
            'credit_card', 'cc' => 'Credit Card',
            null, '' => '-',
            default => strtoupper(str_replace('_', ' ', $method)),
        };
    }

    private function statusLabel(?string $status): string
    {
        if (in_array($status, self::SUCCESS_STATUSES, true)) {
            return 'Sukses';
        }
        if (in_array($status, self::PENDING_STATUSES, true)) {
            return 'Pending';
        }

        return 'Gagal';
    }

    public function simulatePayment(Transaction $transaction): RedirectResponse
    {
        if ($transaction->status === 'completed') {
            return redirect()
                ->route('admin.transactions.index')
                ->with('success', 'Transaksi sudah dalam status completed.');
        }

        DB::transaction(function () use ($transaction) {
            $oldTransaction = [
                'reference_code' => $transaction->reference_code,
                'status' => $transaction->status,
            ];
            $transaction->update([
                'status' => 'completed',
                'paid_at' => now(),
            ]);

            if ($transaction->membership_plan_id && $transaction->member_profile_id) {
                $plan = MembershipPlan::find($transaction->membership_plan_id);

                if ($plan) {
                    $durationDays = match ($plan->billing_period) {
                        'daily' => 1,
                        'monthly' => 30,
                        'yearly' => 365,
                        default => 30,
                    };

                    $existingMembership = MemberMembership::query()
                        ->where('member_profile_id', $transaction->member_profile_id)
                        ->where('status', 'active')
                        ->first();

                    if ($existingMembership) {
                        $oldMembership = [
                            'start_date' => $existingMembership->start_date?->toDateString(),
                            'end_date' => $existingMembership->end_date?->toDateString(),
                            'status' => $existingMembership->status,
                        ];
                        $existingMembership->update([
                            'end_date' => Carbon::parse($existingMembership->end_date)->addDays($durationDays),
                        ]);
                        ActivityLogger::log(
                            action: 'membership_renewed',
                            model: $existingMembership,
                            oldData: $oldMembership,
                            newData: [
                                'start_date' => $existingMembership->start_date?->toDateString(),
                                'end_date' => $existingMembership->end_date?->toDateString(),
                                'status' => $existingMembership->status,
                                'source' => 'Web Admin',
                            ],
                            description: "Membership diperpanjang melalui simulasi transaksi {$transaction->reference_code}",
                        );
                    } else {
                        $membership = MemberMembership::create([
                            'member_profile_id' => $transaction->member_profile_id,
                            'membership_plan_id' => $transaction->membership_plan_id,
                            'transaction_id' => $transaction->id,
                            'start_date' => now(),
                            'end_date' => now()->addDays($durationDays),
                            'status' => 'active',
                            'payment_status' => 'paid',
                        ]);
                        ActivityLogger::log(
                            action: 'membership_created',
                            model: $membership,
                            newData: [
                                'member_profile_id' => $membership->member_profile_id,
                                'membership_plan_id' => $membership->membership_plan_id,
                                'start_date' => $membership->start_date?->toDateString(),
                                'end_date' => $membership->end_date?->toDateString(),
                                'status' => $membership->status,
                                'payment_status' => $membership->payment_status,
                                'source' => 'Web Admin',
                            ],
                            description: "Membership diaktifkan melalui simulasi transaksi {$transaction->reference_code}",
                        );
                    }
                }
            }

            ActivityLogger::logAction(
                'simulate_payment',
                "Pembayaran disimulasikan: {$transaction->reference_code}",
            );
            ActivityLogger::log(
                action: 'transaction_payment_completed',
                model: $transaction,
                oldData: $oldTransaction,
                newData: [
                    'reference_code' => $transaction->reference_code,
                    'status' => $transaction->status,
                    'amount' => $transaction->amount,
                    'fee' => $transaction->fee,
                    'total_payment' => $transaction->total_payment,
                    'source' => 'Web Admin',
                ],
                description: "Pembayaran membership disimulasikan: {$transaction->reference_code}",
            );
        });

        return redirect()
            ->route('admin.transactions.index')
            ->with('success', "Pembayaran {$transaction->reference_code} berhasil disimulasikan. Membership sudah aktif.");
    }
}
