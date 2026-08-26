<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MemberMembership;
use App\Models\MembershipPlan;
use App\Models\TrainerProfile;
use App\Models\Transaction;
use App\Services\ActivityLogger;
use App\Services\Admin\AuditTrailQueryService;
use App\Services\Admin\AuditTrailWorkbookService;
use App\Support\AuditTrailFormatter;
use Illuminate\Contracts\View\View;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AuditTrailController extends Controller
{
    public const CATEGORY_LABELS = [
        'all' => 'Semua',
        'admin_auth' => 'Autentikasi Admin',
        'admin_account' => 'Akun Admin',
        'finance' => 'Keuangan',
        'membership' => 'Keanggotaan',
        'trainer' => 'Personal Trainer',
    ];

    private const ADMIN_AUTH_ACTIONS = ['admin_login', 'admin_logout'];

    private const ADMIN_ACCOUNT_ACTIONS = [
        'admin_account_created', 'admin_account_updated',
        'admin_account_activated', 'admin_account_deactivated',
    ];

    private const FINANCE_ACTIONS = [
        'transaction_created', 'transaction_status_changed',
        'transaction_payment_completed', 'pakasir_webhook_updated',
        'created', 'updated',
    ];

    private const MEMBERSHIP_ACTIONS = [
        'membership_created', 'membership_renewed', 'created', 'updated', 'deleted',
    ];

    private const TRAINER_ACTIONS = ['created', 'updated', 'deleted'];

    public function __construct(
        private readonly AuditTrailWorkbookService $auditWorkbook,
        private readonly AuditTrailQueryService $auditQuery,
    ) {}

    public function index(Request $request): View
    {
        $logs = $this->buildQuery($request)
            ->latest()
            ->paginate(5)
            ->withQueryString();

        return view('admin.audit-trail.index', [
            'logs' => $logs,
            'search' => $request->query('search', ''),
            'actor' => $request->query('actor', 'all'),
            'category' => $request->query('category', 'all'),
            'dateRange' => $request->query('date', 'all'),
            'categoryLabels' => self::CATEGORY_LABELS,
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        $rows = $this->buildQuery($request)->latest()->get();
        $now = now(config('app.timezone'));
        $filename = 'audit-trail-egggym-'.$now->format('Y-m-d-Hi').'.xlsx';
        $workbook = $this->auditWorkbook->build($rows, $this->exportFilters($request, $now));

        ActivityLogger::logAction('export_audit', "Export audit log ({$rows->count()} baris).");

        return response()->streamDownload(function () use ($workbook) {
            (new Xlsx($workbook))->save('php://output');
            $workbook->disconnectWorksheets();
        }, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Cache-Control' => 'max-age=0, no-cache, no-store, must-revalidate',
        ]);
    }

    private function exportFilters(Request $request, \Illuminate\Support\Carbon $now): array
    {
        $category = array_key_exists($request->query('category', 'all'), self::CATEGORY_LABELS)
            ? $request->query('category', 'all')
            : 'all';
        $actor = $request->query('actor', 'all');
        $date = $request->query('date', 'all');

        return [
            'exported_at' => $now,
            'date_label' => match ($date) {
                'today' => $now->locale('id')->translatedFormat('d F Y'),
                'week' => $now->copy()->startOfWeek()->locale('id')->translatedFormat('d F Y')
                    .' - '.$now->copy()->endOfWeek()->locale('id')->translatedFormat('d F Y'),
                'month' => $now->locale('id')->translatedFormat('F Y'),
                default => 'Semua Tanggal',
            },
            'category_label' => self::CATEGORY_LABELS[$category],
            'actor_label' => match ($actor) {
                'admin' => 'Admin',
                'member' => 'Member',
                'trainer' => 'Personal Trainer',
                'system' => 'Sistem',
                default => 'Semua Pelaku',
            },
            'search' => trim((string) $request->query('search', '')),
        ];
    }

    private function buildQuery(Request $request): Builder
    {
        return $this->auditQuery->filtered($request, self::CATEGORY_LABELS);
    }

    public static function categoryFor(ActivityLog $log): string
    {
        if (in_array($log->action, self::ADMIN_AUTH_ACTIONS, true)) {
            return 'admin_auth';
        }
        if (in_array($log->action, self::ADMIN_ACCOUNT_ACTIONS, true)) {
            return 'admin_account';
        }
        if ($log->model_type === Transaction::class) {
            return 'finance';
        }
        if (in_array($log->model_type, [MemberMembership::class, MembershipPlan::class], true)) {
            return 'membership';
        }

        return 'trainer';
    }

    public static function resolveRole(ActivityLog $log): string
    {
        return $log->user ? strtoupper($log->user->role?->name ?? 'ADMIN') : 'SYSTEM';
    }

    public static function resolveStatus(ActivityLog $log): array
    {
        $data = self::safeData($log->new_data);
        $status = strtolower((string) ($data['status'] ?? ''));
        if (in_array($status, ['failed', 'expired', 'cancelled'], true)) {
            return ['label' => strtoupper($status), 'type' => $status === 'failed' ? 'danger' : 'warning'];
        }
        if (str_contains($log->action, 'deactivated') || $log->action === 'admin_logout') {
            return ['label' => 'SUCCESS', 'type' => 'success'];
        }

        return ['label' => 'SUCCESS', 'type' => 'success'];
    }

    public static function resolveTarget(ActivityLog $log): string
    {
        $data = self::safeData($log->new_data) + self::safeData($log->old_data);
        if (in_array($log->action, self::ADMIN_AUTH_ACTIONS, true)) {
            return $data['email'] ?? $log->user?->email ?? 'Akun Admin';
        }
        if (in_array($log->action, self::ADMIN_ACCOUNT_ACTIONS, true)) {
            return $data['email'] ?? $data['name'] ?? 'Akun Admin';
        }
        if ($log->model_type === Transaction::class) {
            $transaction = Transaction::with(['memberProfile.user', 'membershipPlan'])->find($log->model_id);

            return collect([
                $data['reference_code'] ?? $transaction?->reference_code,
                $data['member_name'] ?? $transaction?->memberProfile?->user?->name,
                $data['membership_plan_name'] ?? $transaction?->membershipPlan?->name,
            ])->filter()->implode(' • ') ?: "Transaksi #{$log->model_id}";
        }
        if ($log->model_type === MemberMembership::class) {
            $membership = MemberMembership::with(['memberProfile.user', 'membershipPlan'])->find($log->model_id);

            return collect([
                $data['member_name'] ?? $membership?->memberProfile?->user?->name,
                $data['membership_plan_name'] ?? $membership?->membershipPlan?->name,
                $data['status'] ?? $membership?->status,
            ])->filter()->implode(' • ') ?: "Membership #{$log->model_id}";
        }
        if ($log->model_type === MembershipPlan::class) {
            return $data['name'] ?? MembershipPlan::withTrashed()->find($log->model_id)?->name ?? "Paket #{$log->model_id}";
        }

        $trainer = TrainerProfile::with('user')->find($log->model_id);

        return collect([$trainer?->user?->name, $trainer?->user?->email, $trainer?->id])
            ->filter(fn ($value) => $value !== null && $value !== '')
            ->implode(' • ') ?: "Personal Trainer #{$log->model_id}";
    }

    public static function resolveSource(ActivityLog $log): string
    {
        $data = self::safeData($log->new_data) + self::safeData($log->old_data);

        return (string) ($data['source'] ?? ($log->user_id ? 'Web Admin' : 'Sistem'));
    }

    public static function safeChanges(ActivityLog $log): array
    {
        return AuditTrailFormatter::details($log) ?? [];
    }

    private static function safeData(mixed $data): array
    {
        return AuditTrailFormatter::safeData($data);
    }
}
