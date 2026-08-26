@extends('admin.layouts.app')

@php
    $title = 'Pembayaran & Transaksi - EggGym Admin';
    $pageHeading = 'Pembayaran & Transaksi';
    $pageSubheading = 'Pantau pendapatan, transaksi, dan status pembayaran member.';

    $methodLabel = function ($m) {
        return match ($m) {
            'qris' => 'QRIS',
            'virtual_account' => 'Virtual Account',
            'bni_va' => 'VA BNI',
            'bri_va' => 'VA BRI',
            'bca_va' => 'VA BCA',
            'mandiri_va' => 'VA Mandiri',
            'credit_card', 'cc' => 'Credit Card',
            null, '' => '-',
            default => strtoupper(str_replace('_', ' ', $m)),
        };
    };
    $statusMeta = function ($status) {
        if (in_array($status, ['completed', 'paid'])) return ['label' => 'Sukses', 'cls' => 'tx-badge-sukses'];
        if (in_array($status, ['pending', 'waiting', 'waiting_payment'])) return ['label' => 'Pending', 'cls' => 'tx-badge-pending'];
        return ['label' => 'Gagal', 'cls' => 'tx-badge-gagal'];
    };
    // Query string aktif untuk menjaga filter saat export/pagination.
    $activeQuery = ['search' => $search, 'status' => $status, 'date' => $dateFilter, 'membership_package_id' => $membershipPackageId, 'metode' => $metode];
@endphp

@section('content')
    <style>
        /* STAT CARDS */
        .tx-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-bottom: 24px; }
        .tx-stat { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 22px; box-shadow: var(--shadow-card); }
        .tx-stat__label { font-size: 11px; font-weight: 600; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); margin-bottom: 10px; }
        .tx-stat__value { font-size: 30px; font-weight: 800; color: var(--text); line-height: 1; }
        .tx-stat__value.is-accent { color: var(--accent); }
        .tx-stat__caption { font-size: 11px; margin-top: 8px; color: var(--muted); }
        .tx-stat__caption.is-up { color: #22C55E; }

        /* FILTER ROW */
        .tx-filter { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 20px; flex-wrap: wrap; }
        .tx-filter form { display: flex; align-items: center; gap: 10px; flex: 0 1 auto; flex-wrap: wrap; }
        .tx-select {
            height: 40px; background: var(--panel); border: 1px solid var(--border); border-radius: 6px;
            width: auto; padding: 0 34px 0 12px; font-size: 13px; color: var(--text); min-width: 148px;
        }
        .tx-select:hover { border-color: var(--accent); }
        .tx-export { margin-left: auto; white-space: nowrap; }

        /* TABLE */
        .tx-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; box-shadow: var(--shadow-card); }
        .tx-grid { display: grid; grid-template-columns: minmax(145px,1.25fr) minmax(150px,1.5fr) minmax(135px,1.35fr) minmax(115px,1.05fr) minmax(120px,1.1fr) minmax(110px,1.05fr) minmax(90px,.8fr); gap: 14px; align-items: center; }
        .tx-thead { background: var(--bg); padding: 14px 20px; font-size: 11px; font-weight: 700; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .tx-row { padding: 16px 20px; border-top: 1px solid var(--border); transition: background 0.15s ease; }
        .tx-row:hover { background: var(--panel-soft); }
        .tx-kode { min-width: 0; font-size: 13px; font-weight: 700; line-height: 1.35; color: var(--accent); font-family: "JetBrains Mono", monospace; }
        .tx-kode__prefix, .tx-kode__body { display: block; }
        .tx-kode__body { overflow-wrap: anywhere; word-break: break-word; }
        .tx-membership-name { overflow-wrap: anywhere; word-break: normal; }
        .tx-member { display: flex; align-items: center; gap: 10px; }
        .tx-avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--panel-soft); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; color: var(--accent); flex-shrink: 0; }
        .tx-member__name { font-size: 14px; font-weight: 600; color: var(--text); }
        .tx-cell { font-size: 13px; color: var(--text); }
        .tx-cell-muted { font-size: 12px; color: var(--muted); }
        .tx-nominal { font-size: 14px; font-weight: 700; color: var(--text); white-space: nowrap; }
        .tx-date { font-size: 12px; color: var(--muted); }
        .tx-badge { display: inline-flex; align-items: center; padding: 4px 14px; border-radius: 999px; font-size: 10px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; }
        .tx-badge-sukses { background: rgba(76,175,80,0.12); border: 1px solid #22C55E; color: #22C55E; }
        .tx-badge-pending { background: rgba(250,204,21,0.12); border: 1px solid var(--accent); color: var(--accent); }
        .tx-badge-gagal { background: #EF4444; color: #fff; }

        .tx-empty { padding: 40px 20px; text-align: center; color: var(--muted); }
        .tx-loading {
            position: fixed; inset: 0; z-index: 100; display: flex; align-items: center;
            justify-content: center; background: rgba(0,0,0,.52); backdrop-filter: blur(2px);
        }
        .tx-loading[hidden] { display: none; }
        .tx-loading__box {
            padding: 14px 18px; border: 1px solid var(--border); border-radius: 8px;
            background: var(--panel); color: var(--text); font-size: 13px; font-weight: 700;
        }

        @media (max-width: 1080px) {
            .tx-stats { grid-template-columns: 1fr 1fr; }
            .tx-panel { overflow-x: auto; }
            .tx-grid { min-width: 940px; }
            .adm-pager-foot { min-width: 940px; }
        }
        @media (max-width: 680px) {
            .tx-filter, .tx-filter form { align-items: stretch; }
            .tx-filter form { width: 100%; }
            .tx-select { flex: 1 1 150px; }
            .tx-export { width: 100%; margin-left: 0; }
            .tx-stats { grid-template-columns: 1fr; }
        }
    </style>

    @if (session('success'))
        <div class="flash">{{ session('success') }}</div>
    @endif
    @if (session('error'))
        <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">{{ session('error') }}</div>
    @endif

    <div class="tx-loading" id="transactionLoading" hidden aria-live="polite" aria-busy="true">
        <div class="tx-loading__box">Memuat transaksi...</div>
    </div>

    {{-- (2) STAT CARDS --}}
    <div class="tx-stats">
        <div class="tx-stat">
            <div class="tx-stat__label">Total Pendapatan</div>
            <div class="tx-stat__value is-accent">{{ $kpi['revenue_label'] }}</div>
            <div class="tx-stat__caption">
                {{ $kpi['revenue_caption'] }}
                @if($kpi['net_unknown_count'] > 0)
                    <br>{{ $kpi['net_unknown_count'] }} transaksi lama tanpa data fee tidak dihitung
                @endif
            </div>
        </div>
        <div class="tx-stat">
            <div class="tx-stat__label">Member Bertransaksi</div>
            <div class="tx-stat__value">{{ number_format($kpi['successful_member_count'], 0, ',', '.') }}</div>
            <div class="tx-stat__caption">{{ $kpi['successful_member_caption'] }}</div>
        </div>
        <div class="tx-stat">
            <div class="tx-stat__label">Rata-rata Transaksi</div>
            <div class="tx-stat__value">{{ $kpi['average_transaction_label'] }}</div>
            <div class="tx-stat__caption">{{ $kpi['average_transaction_caption'] }}</div>
        </div>
        <div class="tx-stat">
            <div class="tx-stat__label">Member Tetap Aktif</div>
            <div class="tx-stat__value">{{ $kpi['renewal_label'] }}</div>
            <div class="tx-stat__caption">
                @if($kpi['renewal_rate'] === null)
                    Data perpanjangan membership belum mencukupi
                @else
                    {{ $kpi['renewal_members'] }} dari {{ $kpi['renewal_eligible'] }} member memperpanjang pada {{ $kpi['period_label'] }}
                @endif
            </div>
        </div>
    </div>

    {{-- (3) FILTER ROW --}}
    <div class="tx-filter">
        <form method="GET" action="{{ route('admin.transactions.index') }}" data-transaction-filter>
            @if($search !== '')<input type="hidden" name="search" value="{{ $search }}">@endif
            @if($status !== '')<input type="hidden" name="status" value="{{ $status }}">@endif
            <select name="date" class="tx-select" onchange="this.form.submit()">
                <option value="">&#128197; Semua Tanggal</option>
                <option value="today" {{ $dateFilter === 'today' ? 'selected' : '' }}>Hari Ini</option>
                <option value="week" {{ $dateFilter === 'week' ? 'selected' : '' }}>Minggu Ini</option>
                <option value="month" {{ $dateFilter === 'month' ? 'selected' : '' }}>Bulan Ini</option>
            </select>
            <select name="membership_package_id" class="tx-select" onchange="this.form.submit()">
                <option value="">Membership: Semua</option>
                @foreach ($membershipOptions as $membershipOption)
                    <option value="{{ $membershipOption->id }}" {{ (string) $membershipPackageId === (string) $membershipOption->id ? 'selected' : '' }}>{{ $membershipOption->name }}</option>
                @endforeach
            </select>
            <select name="metode" class="tx-select" onchange="this.form.submit()">
                <option value="">&#128179; Metode: Semua</option>
                @foreach ($methodOptions as $m)
                    <option value="{{ $m }}" {{ $metode === $m ? 'selected' : '' }}>{{ $methodLabel($m) }}</option>
                @endforeach
            </select>
        </form>
        <a href="{{ route('admin.transactions.export-ledger', array_filter($activeQuery)) }}" class="btn btn-primary tx-export">&#11015; Export Excel</a>
    </div>

    {{-- (4) TABLE --}}
    <div class="tx-panel">
        <div class="tx-grid tx-thead">
            <div>Kode Transaksi</div>
            <div>Member</div>
            <div class="tx-col-jenis">Membership</div>
            <div class="tx-col-metode">Metode</div>
            <div>Nominal</div>
            <div class="tx-col-tanggal">Tanggal</div>
            <div>Status</div>
        </div>

        @forelse ($transactions as $tx)
            @php
                $memberName = $tx->memberProfile?->user?->name ?? 'Member';
                $init = collect(explode(' ', trim($memberName)))->filter()->take(2)->map(fn ($w) => mb_strtoupper(mb_substr($w, 0, 1)))->implode('');
                $sm = $statusMeta($tx->status);
                $membershipName = $tx->membershipPlan?->name ?? 'Paket tidak tersedia';
                $referenceCode = (string) $tx->reference_code;
                $referenceParts = preg_match('/^(\D+)(.+)$/u', $referenceCode, $matches) === 1
                    ? [$matches[1], $matches[2]]
                    : [null, $referenceCode];
                $nominal = (float) $tx->amount;
                $dateObj = $tx->paid_at ?? $tx->created_at;
            @endphp
            <div class="tx-grid tx-row">
                <div class="tx-kode" title="{{ $referenceCode }}">
                    @if($referenceParts[0] !== null)<span class="tx-kode__prefix">{{ $referenceParts[0] }}</span>@endif
                    <span class="tx-kode__body">{{ $referenceParts[1] }}</span>
                </div>
                <div class="tx-member">
                    <div class="tx-avatar"><x-member-avatar :avatar-url="$tx->memberProfile?->user?->avatar_url" :initials="$init !== '' ? $init : 'M'" :name="$memberName" /></div>
                    <div class="tx-member__name">{{ $memberName }}</div>
                </div>
                <div class="tx-col-jenis tx-cell tx-membership-name">{{ $membershipName }}</div>
                <div class="tx-col-metode tx-cell">{{ $methodLabel($tx->payment_method) }}</div>
                <div class="tx-nominal">Rp {{ number_format($nominal, 0, ',', '.') }}</div>
                    <div class="tx-col-tanggal tx-date">{{ $dateObj?->locale('id')->translatedFormat('d F Y') ?? '-' }}<br>{{ optional($dateObj)->format('H:i') }}</div>
                <div><span class="tx-badge {{ $sm['cls'] }}">{{ $sm['label'] }}</span></div>
            </div>
        @empty
            <div class="tx-empty">{{ $search !== '' ? 'Tidak ada data yang cocok.' : 'Belum ada transaksi yang cocok dengan filter saat ini.' }}</div>
        @endforelse

        @include('admin.partials.pagination', ['paginator' => $transactions, 'itemLabel' => 'transaksi'])
    </div>
    <script>
        (() => {
            const loading = document.getElementById('transactionLoading');
            const showLoading = () => { loading.hidden = false; };
            document.querySelector('[data-transaction-filter]')?.addEventListener('submit', showLoading);
            document.querySelectorAll('.tx-panel .adm-pager a').forEach((link) => {
                link.addEventListener('click', showLoading);
            });
        })();
    </script>
@endsection
