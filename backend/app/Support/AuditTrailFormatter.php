<?php

namespace App\Support;

use App\Models\ActivityLog;
use App\Models\MemberMembership;
use App\Models\MembershipPlan;
use App\Models\TrainerProfile;
use App\Models\Transaction;

class AuditTrailFormatter
{
    private const SENSITIVE_KEYS = [
        'password', 'remember_token', 'token', 'session', 'csrf', 'secret',
        'provider_payload', 'payment_number', 'bank_', 'dana_', 'other_payment_',
    ];

    private const LABELS = [
        'name' => 'Nama Petugas',
        'email' => 'Email',
        'status' => 'Status Akun',
        'is_admin_owner' => 'Admin Utama',
        'reference_code' => 'Kode Transaksi',
        'membership' => 'Membership',
        'amount' => 'Harga Membership',
        'fee' => 'Biaya Layanan',
        'total_payment' => 'Total Dibayar Member',
        'net_amount' => 'Pendapatan Bersih',
        'payment_method' => 'Metode Pembayaran',
        'membership_plan' => 'Paket Membership',
        'start_date' => 'Tanggal Mulai',
        'end_date' => 'Tanggal Berakhir',
        'tier' => 'Tier',
        'max_clients' => 'Kapasitas Klien Maksimal',
        'verification_status' => 'Status Verifikasi PT',
        'admin_notes' => 'Catatan Admin Internal',
        'account_status' => 'Status Akun',
    ];

    private const VALUES = [
        'active' => 'Aktif', 'inactive' => 'Nonaktif',
        'pending' => 'Pending', 'verified' => 'Terverifikasi',
        'unverified' => 'Belum Terverifikasi', 'success' => 'Sukses',
        'completed' => 'Sukses', 'paid' => 'Sukses', 'failed' => 'Gagal',
        'expired' => 'Kedaluwarsa', 'cancelled' => 'Dibatalkan',
        'standard' => 'Basic', 'pro' => 'Pro', 'elite' => 'Elite',
        'qris' => 'QRIS', 'virtual_account' => 'Virtual Account',
    ];

    public static function details(ActivityLog $log): ?array
    {
        if (in_array($log->action, ['admin_login', 'admin_logout'], true)) {
            return null;
        }

        $old = self::normalize($log, $log->old_data);
        $new = self::normalize($log, $log->new_data);
        $mode = self::mode($log);

        if ($mode === 'update') {
            // Log legacy sering memiliki old_data parsial tetapi new_data satu model penuh.
            // Hanya key berpasangan yang dapat dibuktikan sebagai perubahan.
            $keys = array_intersect(array_keys($old), array_keys($new));
            $rows = collect($keys)->filter(fn (string $key) => self::comparable($old[$key]) !== self::comparable($new[$key]))
                ->map(fn (string $key) => self::row($log, $key, $old[$key], $new[$key]))
                ->values()->all();
        } elseif ($mode === 'create') {
            $rows = collect($new)->map(fn ($value, string $key) => self::row($log, $key, null, $value))->values()->all();
        } else {
            $rows = collect($old ?: $new)->map(fn ($value, string $key) => self::row($log, $key, $value, null))->values()->all();
        }

        if ($rows === []) {
            return null;
        }

        return [
            'mode' => $mode,
            'title' => match ($mode) {
                'create' => 'Lihat Data Dibuat',
                'delete' => 'Lihat Data Sebelumnya',
                default => 'Lihat Perubahan',
            },
            'rows' => $rows,
        ];
    }

    public static function safeData(mixed $data): array
    {
        return collect(is_array($data) ? $data : [])
            ->reject(fn ($value, $key) => collect(self::SENSITIVE_KEYS)
                ->contains(fn (string $sensitive) => str_contains(strtolower((string) $key), $sensitive)))
            ->filter(fn ($value) => ! is_array($value) && ! is_object($value))
            ->all();
    }

    public static function formatValue(mixed $value, string $key): string
    {
        if ($value === null || (is_string($value) && trim($value) === '')) {
            return 'Belum ada';
        }
        if (is_bool($value) || in_array($value, [0, 1, '0', '1'], true) && $key === 'is_admin_owner') {
            return (bool) $value ? 'Ya' : 'Tidak';
        }
        $normalized = strtolower((string) $value);
        if (isset(self::VALUES[$normalized])) {
            return self::VALUES[$normalized];
        }
        if (in_array($key, ['amount', 'fee', 'total_payment', 'net_amount'], true) && is_numeric($value)) {
            return 'Rp '.number_format((float) $value, 0, ',', '.');
        }
        if (in_array($key, ['start_date', 'end_date'], true)) {
            try {
                return \Illuminate\Support\Carbon::parse($value)->locale('id')->translatedFormat('d F Y');
            } catch (\Throwable) {
                // Preserve a legacy value that cannot be parsed.
            }
        }

        return (string) $value;
    }

    private static function normalize(ActivityLog $log, mixed $data): array
    {
        $safe = self::safeData($data);
        $aliases = self::aliases($log);
        $allowed = self::allowed($log);
        $result = [];
        foreach ($safe as $key => $value) {
            $canonical = $aliases[$key] ?? $key;
            if (! in_array($canonical, $allowed, true) || array_key_exists($canonical, $result)) {
                continue;
            }
            $result[$canonical] = $value;
        }
        if ($log->model_type === Transaction::class) {
            if (! array_key_exists('net_amount', $result)
                && isset($safe['total_payment'], $safe['fee'])
                && is_numeric($safe['total_payment']) && is_numeric($safe['fee'])) {
                $result['net_amount'] = (float) $safe['total_payment'] - (float) $safe['fee'];
            }
        }

        return $result;
    }

    private static function allowed(ActivityLog $log): array
    {
        if (str_starts_with($log->action, 'admin_account_')) {
            return ['name', 'email', 'status', 'is_admin_owner'];
        }

        return match ($log->model_type) {
            Transaction::class => ['reference_code', 'membership', 'amount', 'fee', 'total_payment', 'net_amount', 'payment_method', 'status'],
            MemberMembership::class, MembershipPlan::class => ['membership_plan', 'start_date', 'end_date', 'status'],
            TrainerProfile::class => ['tier', 'max_clients', 'verification_status', 'admin_notes', 'account_status'],
            default => [],
        };
    }

    private static function aliases(ActivityLog $log): array
    {
        if ($log->model_type === Transaction::class) {
            return ['membership_plan_name' => 'membership', 'membership_plan' => 'membership'];
        }
        if (in_array($log->model_type, [MemberMembership::class, MembershipPlan::class], true)) {
            return ['membership_plan_name' => 'membership_plan', 'name' => 'membership_plan'];
        }

        return [];
    }

    private static function mode(ActivityLog $log): string
    {
        if (str_contains($log->action, 'created')) {
            return 'create';
        }
        if (str_contains($log->action, 'deleted') || str_contains($log->action, 'deactivated')) {
            return 'delete';
        }

        return 'update';
    }

    private static function row(ActivityLog $log, string $key, mixed $old, mixed $new): array
    {
        return [
            'field' => $key,
            'label' => self::label($log, $key),
            'old' => self::formatValue($old, $key),
            'new' => self::formatValue($new, $key),
        ];
    }

    private static function label(ActivityLog $log, string $key): string
    {
        if ($key === 'status') {
            return match ($log->model_type) {
                Transaction::class => 'Status Pembayaran',
                MemberMembership::class, MembershipPlan::class => 'Status Membership',
                default => 'Status Akun',
            };
        }

        return self::LABELS[$key] ?? str($key)->replace('_', ' ')->title()->toString();
    }

    private static function comparable(mixed $value): string
    {
        return json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: '';
    }
}
