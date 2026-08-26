<?php

namespace Tests\Feature;

use App\Models\MemberMembership;
use App\Models\MemberProfile;
use App\Models\MembershipPlan;
use App\Models\Role;
use App\Models\Transaction;
use App\Models\User;
use App\Services\Admin\MembershipRevenueService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use Tests\TestCase;

class AdminTransactionPresentationTest extends TestCase
{
    use DatabaseTransactions;

    private User $admin;

    private MemberProfile $member;

    private MembershipPlan $plan;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = $this->createUser('admin', 'Transaction Presentation Admin');
        $memberUser = $this->createUser('member', 'Transaction Filter Member');
        $this->member = MemberProfile::create([
            'user_id' => $memberUser->id,
            'member_code' => 'TX-'.uniqid(),
            'joined_at' => now(),
        ]);
        $this->plan = MembershipPlan::create([
            'name' => 'Presentation Membership',
            'slug' => 'presentation-membership-'.uniqid(),
            'description' => 'Transaction presentation fixture',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
    }

    public function test_transactions_use_five_row_backend_pagination_and_compact_read_only_table(): void
    {
        foreach (range(1, 6) as $index) {
            $this->createTransaction($index, $index === 6 ? 'bca_va' : 'qris');
        }
        $this->createPtTransaction('PRESENTATION-TX-PT', 'qris', 9000000);

        $response = $this->adminGet(route('admin.transactions.index', [
            'search' => 'PRESENTATION-TX',
            'metode' => 'qris',
        ]));

        $response->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->perPage() === 5
                && $transactions->count() === 5
                && $transactions->total() === 5
                && $transactions->currentPage() === 1)
            ->assertSeeText('Export Excel')
            ->assertSeeText('Presentation Membership')
            ->assertSeeText('Membership')
            ->assertDontSeeText('Membership (Presentation Membership)')
            ->assertDontSeeText('Personal Trainer Payment')
            ->assertDontSee('name="jenis"', false)
            ->assertDontSeeText('Export Ledger')
            ->assertSee('name="search" value="PRESENTATION-TX"', false)
            ->assertSee('onchange="this.form.submit()"', false)
            ->assertSee('Menampilkan 1&ndash;5 dari 5 transaksi', false)
            ->assertSee('grid-template-columns: minmax(145px,1.25fr)', false)
            ->assertSee('<span class="tx-kode__prefix">PRESENTATION-TX-</span>', false)
            ->assertSee('class="tx-kode__prefix"', false)
            ->assertSee('class="tx-kode__body"', false)
            ->assertDontSee('text-overflow: ellipsis', false)
            ->assertDontSee('data-kebab', false)
            ->assertDontSee('txToggleKebab', false)
            ->assertDontSee('simulate-payment', false)
            ->assertDontSee('Verifikasi Pembayaran', false)
            ->assertDontSee('Aksi transaksi', false);
        $this->assertMatchesRegularExpression(
            '/<span class="tx-kode__body">1-[^<]+<\/span>/',
            $response->getContent()
        );
    }

    public function test_pagination_and_export_keep_real_search_and_filter_query(): void
    {
        foreach (range(1, 7) as $index) {
            $this->createTransaction($index, 'qris');
        }
        $this->createPtTransaction('PRESENTATION-TX-PT-EXPORT', 'qris', 9000000);

        $firstPage = $this->adminGet(route('admin.transactions.index', [
            'search' => 'PRESENTATION-TX',
            'metode' => 'qris',
        ]));
        $firstPage->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->perPage() === 5
                && $transactions->count() === 5
                && $transactions->total() === 7)
            ->assertSee('search=PRESENTATION-TX', false)
            ->assertDontSee('jenis=', false)
            ->assertSee('metode=qris', false)
            ->assertSee('rel="next">Next</a>', false);

        $this->adminGet(route('admin.transactions.index', [
            'search' => 'PRESENTATION-TX',
            'metode' => 'qris',
            'page' => 2,
        ]))->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->currentPage() === 2
                && $transactions->count() === 2)
            ->assertSee('rel="prev">Prev</a>', false)
            ->assertSee('class="adm-pager__nav is-disabled">Next</span>', false);

        $export = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.transactions.export-ledger', [
                'search' => 'PRESENTATION-TX',
                'metode' => 'qris',
            ]));
        $export->assertOk()
            ->assertHeader('content-type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            ->assertHeader('content-disposition', 'attachment; filename=laporan-transaksi-membership-'.now()->format('Y-m-d').'.xlsx');
        $content = $export->streamedContent();
        $this->assertStringStartsWith('PK', $content);
        $workbook = $this->loadWorkbook($content);
        $this->assertSame(['Ringkasan', 'Transaksi Membership'], $workbook->getSheetNames());

        $summary = $workbook->getSheetByName('Ringkasan');
        $this->assertSame('Semua Tanggal', $summary->getCell('B2')->getValue());
        $this->assertSame(7, $summary->getCell('B3')->getValue());
        $this->assertSame(3, $summary->getCell('B4')->getValue());
        $this->assertSame(0, $summary->getCell('B5')->getValue());
        $this->assertSame(300012.0, $summary->getCell('B6')->getValue());
        $this->assertSame(7500.0, $summary->getCell('B7')->getValue());
        $this->assertSame(307512.0, $summary->getCell('B8')->getValue());
        $this->assertSame(300012.0, $summary->getCell('B9')->getValue());

        $sheet = $workbook->getSheetByName('Transaksi Membership');
        $this->assertSame('Kode Transaksi', $sheet->getCell('A1')->getValue());
        $this->assertSame('Metode Pembayaran', $sheet->getCell('D1')->getValue());
        $this->assertSame('Waktu', $sheet->getCell('J1')->getValue());
        $this->assertSame(DataType::TYPE_STRING, $sheet->getCell('A2')->getDataType());
        $this->assertSame(DataType::TYPE_NUMERIC, $sheet->getCell('E2')->getDataType());
        $this->assertSame(DataType::TYPE_NUMERIC, $sheet->getCell('I2')->getDataType());
        $this->assertSame(DataType::TYPE_NUMERIC, $sheet->getCell('J2')->getDataType());
        $this->assertSame('A2', $sheet->getFreezePane());
        $this->assertSame('A1:K8', $sheet->getAutoFilter()->getRange());
        $this->assertStringContainsString('Rp', $sheet->getStyle('E2')->getNumberFormat()->getFormatCode());
        $this->assertSame('dd mmmm yyyy', $sheet->getStyle('I2')->getNumberFormat()->getFormatCode());
        $this->assertSame('hh:mm', $sheet->getStyle('J2')->getNumberFormat()->getFormatCode());
        $values = implode('|', $sheet->toArray(null, true, true, false)[0] ?? []);
        $this->assertStringNotContainsString('PRESENTATION-TX-PT-EXPORT', $values);
        $workbook->disconnectWorksheets();
    }

    public function test_membership_package_filter_combines_with_search_method_pagination_and_export(): void
    {
        $otherPlan = MembershipPlan::create([
            'name' => 'Other Membership Package',
            'slug' => 'other-membership-'.uniqid(),
            'description' => 'Package filter fixture',
            'price' => 200000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        $newPlanWithoutTransaction = MembershipPlan::create([
            'name' => 'Brand New Membership',
            'slug' => 'brand-new-membership-'.uniqid(),
            'description' => 'Must appear before first purchase',
            'price' => 300000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        $inactivePlan = MembershipPlan::create([
            'name' => 'Inactive Membership Package',
            'slug' => 'inactive-membership-'.uniqid(),
            'description' => 'Must not appear as a specific filter',
            'price' => 300000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => false,
        ]);
        $upcomingPlan = MembershipPlan::create([
            'name' => 'Upcoming Membership Package',
            'slug' => 'upcoming-membership-'.uniqid(),
            'description' => 'Must not appear before release',
            'price' => 300000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
            'release_date' => now()->addMonth()->toDateString(),
        ]);
        foreach (range(1, 6) as $index) {
            $this->createTransaction($index, 'qris');
        }
        $excluded = $this->createTransaction(99, 'qris');
        $excluded->update(['membership_plan_id' => $otherPlan->id]);

        $query = [
            'search' => 'PRESENTATION-TX',
            'membership_package_id' => $this->plan->id,
            'metode' => 'qris',
        ];
        $response = $this->adminGet(route('admin.transactions.index', $query));
        $response->assertOk()
            ->assertViewHas('membershipOptions', fn ($options) => $options->contains('id', $this->plan->id)
                && $options->contains('id', $otherPlan->id)
                && $options->contains('id', $newPlanWithoutTransaction->id)
                && ! $options->contains('id', $inactivePlan->id)
                && ! $options->contains('id', $upcomingPlan->id))
            ->assertViewHas('transactions', fn ($transactions) => $transactions->perPage() === 5
                && $transactions->count() === 5
                && $transactions->total() === 6)
            ->assertSee('name="membership_package_id"', false)
            ->assertSee('value="'.$this->plan->id.'" selected', false)
            ->assertSee('membership_package_id='.$this->plan->id, false)
            ->assertSee('search=PRESENTATION-TX', false)
            ->assertSee('metode=qris', false)
            ->assertSeeText('Member Bertransaksi')
            ->assertSeeText('Other Membership Package')
            ->assertSeeText('Brand New Membership')
            ->assertDontSeeText('Inactive Membership Package')
            ->assertDontSeeText('Upcoming Membership Package')
            ->assertSee('data-transaction-filter', false)
            ->assertSeeText('Memuat transaksi...')
            ->assertSee("document.querySelectorAll('.tx-panel .adm-pager a')", false)
            ->assertDontSeeText($excluded->reference_code);
        $filteredKpi = $response->viewData('kpi');
        $this->assertSame(1, $filteredKpi['successful_member_count']);
        $this->assertSame('Member unik dengan transaksi sukses', $filteredKpi['successful_member_caption']);

        $this->adminGet(route('admin.transactions.index', $query + ['page' => 2]))
            ->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->currentPage() === 2
                && $transactions->count() === 1);

        $export = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.transactions.export-ledger', $query));
        $workbook = $this->loadWorkbook($export->streamedContent());
        $rows = $workbook->getSheetByName('Transaksi Membership')->toArray();
        $serializedRows = json_encode($rows, JSON_THROW_ON_ERROR);
        $this->assertStringContainsString('Presentation Membership', $serializedRows);
        $this->assertStringNotContainsString('Other Membership Package', $serializedRows);
        $this->assertStringNotContainsString($excluded->reference_code, $serializedRows);
        $workbook->disconnectWorksheets();
    }

    public function test_all_memberships_keeps_historical_transactions_from_inactive_plan(): void
    {
        $inactivePlan = MembershipPlan::create([
            'name' => 'Historical Inactive Membership',
            'slug' => 'historical-inactive-'.uniqid(),
            'description' => 'Historical transaction fixture',
            'price' => 450000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => false,
        ]);
        $transaction = $this->createTransaction(77, 'qris');
        $transaction->update(['membership_plan_id' => $inactivePlan->id]);

        $this->adminGet(route('admin.transactions.index', [
            'search' => $transaction->reference_code,
        ]))->assertOk()
            ->assertViewHas('membershipOptions', fn ($options) => ! $options->contains('id', $inactivePlan->id))
            ->assertViewHas('transactions', fn ($transactions) => $transactions->total() === 1)
            ->assertSee('title="'.$transaction->reference_code.'"', false)
            ->assertSeeText('Historical Inactive Membership');
    }

    public function test_payment_kpis_use_success_paid_at_and_real_contiguous_membership_renewals(): void
    {
        $this->travelTo(CarbonImmutable::parse('2035-03-20 12:00:00', 'Asia/Jakarta'));
        $plan = $this->plan;
        $renewedMember = $this->member;
        $notRenewedUser = $this->createUser('member', 'Not Renewed Member');
        $notRenewedMember = MemberProfile::create([
            'user_id' => $notRenewedUser->id,
            'member_code' => 'NO-RENEW-'.uniqid(),
            'joined_at' => '2035-01-01',
        ]);

        $this->createKpiTransaction('KPI-CURRENT-1', 'completed', 100000, '2035-03-05 10:00:00');
        $this->createKpiTransaction('KPI-CURRENT-2', 'paid', 200000, '2035-03-10 10:00:00');
        $this->createKpiTransaction('KPI-LAST', 'completed', 50000, '2035-02-10 10:00:00');
        $this->createKpiTransaction('KPI-PENDING', 'pending', 9000000, null);
        $this->createKpiTransaction('KPI-FAILED', 'failed', 8000000, '2035-03-12 10:00:00');
        $this->createKpiTransaction('KPI-LEGACY', 'completed', 7000000, '2035-03-13 10:00:00', false);
        $this->createPtTransaction('KPI-PT-SUCCESS', 'qris', 99000000, 'completed', '2035-03-15 10:00:00');

        $expiredRenewed = MemberMembership::create([
            'member_profile_id' => $renewedMember->id,
            'membership_plan_id' => $plan->id,
            'start_date' => '2035-02-01',
            'end_date' => '2035-03-02',
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
        MemberMembership::create([
            'member_profile_id' => $renewedMember->id,
            'membership_plan_id' => $plan->id,
            'start_date' => $expiredRenewed->end_date->copy()->addDay(),
            'end_date' => '2035-04-01',
            'status' => 'active',
            'payment_status' => 'paid',
        ]);
        MemberMembership::create([
            'member_profile_id' => $notRenewedMember->id,
            'membership_plan_id' => $plan->id,
            'start_date' => '2035-02-10',
            'end_date' => '2035-03-11',
            'status' => 'expired',
            'payment_status' => 'paid',
        ]);

        $response = $this->adminGet(route('admin.transactions.index', ['search' => 'KPI-']));
        $response->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_label'] === 'Rp 350.000'
                && $kpi['average_transaction_value'] === 116666.66666666667
                && $kpi['average_transaction_label'] === 'Rp 116.667'
                && $kpi['average_transaction_caption'] === 'Dari transaksi membership sukses'
                && $kpi['net_known_count'] === 3
                && $kpi['net_unknown_count'] === 1
                && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
                && $kpi['successful_member_count'] === 1
                && $kpi['successful_member_caption'] === 'Member unik dengan transaksi sukses'
                && $kpi['renewal_rate'] === 50.0
                && $kpi['renewal_members'] === 1
                && $kpi['renewal_eligible'] === 2
                && $kpi['period_label'] === 'Maret 2035')
            ->assertSeeText('Total Pendapatan')
            ->assertSeeText('Member Bertransaksi')
            ->assertDontSeeText('Pendapatan Membership')
            ->assertDontSeeText('Total Biaya Layanan')
            ->assertSeeText('Seluruh transaksi Membership sukses')
            ->assertSeeText('1 transaksi lama tanpa data fee tidak dihitung')
            ->assertSeeText('Rata-rata Transaksi')
            ->assertSeeText('Rp 116.667')
            ->assertSeeText('Dari transaksi membership sukses')
            ->assertDontSeeText('Transaksi Berhasil')
            ->assertSeeText('Member Tetap Aktif')
            ->assertSeeText('1 dari 2 member memperpanjang pada Maret 2035')
            ->assertDontSeeText('Pending Approval')
            ->assertDontSeeText('Menunggu Verifikasi')
            ->assertDontSeeText('Elite tier loyalty');
    }

    public function test_total_revenue_follows_all_filters_across_full_results_table_and_export(): void
    {
        $this->travelTo(CarbonImmutable::parse('2036-07-25 12:00:00', 'Asia/Jakarta'));
        $annualPro = MembershipPlan::create([
            'name' => 'Annual Pro Filtered',
            'slug' => 'annual-pro-filtered-'.uniqid(),
            'description' => 'Filtered total revenue fixture',
            'price' => 100000,
            'duration_days' => 365,
            'billing_period' => 'yearly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        $prefix = 'FILTERED-TOTAL-'.uniqid().'-';

        $this->createFilteredRevenueTransaction($prefix.'ANNUAL-BNI-TODAY', $annualPro, 'bni_va', 'completed', 100001, '2036-07-25 08:00:00');
        $this->createFilteredRevenueTransaction($prefix.'ANNUAL-BNI-PAST', $annualPro, 'bni_va', 'paid', 200002, '2036-06-20 08:00:00');
        foreach (range(1, 5) as $index) {
            $this->createFilteredRevenueTransaction($prefix.'ANNUAL-BNI-PAGE-'.$index, $annualPro, 'bni_va', 'completed', 10000 + $index, '2036-05-20 08:00:00');
        }
        $this->createFilteredRevenueTransaction($prefix.'ANNUAL-QRIS', $annualPro, 'qris', 'completed', 300003, '2036-06-21 08:00:00');
        $this->createFilteredRevenueTransaction($prefix.'STARTER-BNI-TODAY', $this->plan, 'bni_va', 'completed', 400004, '2036-07-25 09:00:00');
        $this->createFilteredRevenueTransaction($prefix.'STARTER-QRIS-PAST', $this->plan, 'qris', 'completed', 500005, '2036-06-22 08:00:00');
        $this->createFilteredRevenueTransaction($prefix.'PENDING', $annualPro, 'bni_va', 'pending', 9000000, null);
        $this->createFilteredRevenueTransaction($prefix.'FAILED', $annualPro, 'bni_va', 'failed', 8000000, '2036-07-25 10:00:00');
        $this->createPtTransaction($prefix.'PT', 'bni_va', 99000000, 'completed', '2036-07-25 11:00:00');

        $default = $this->adminGet(route('admin.transactions.index'));
        $defaultSummary = app(MembershipRevenueService::class)->summarizeSuccessfulQuery(
            Transaction::query()->whereNotNull('membership_plan_id')
        );
        $default->assertOk()->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === $defaultSummary['net']
            && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
            && $kpi['successful_member_count'] === $defaultSummary['successful_member_count']
            && $kpi['successful_member_caption'] === 'Member unik dengan transaksi sukses');

        $today = $this->adminGet(route('admin.transactions.index', ['search' => $prefix, 'date' => 'today']));
        $today->assertOk()->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 500005.0
            && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
            && $kpi['successful_member_count'] === 1);

        $annual = $this->adminGet(route('admin.transactions.index', [
            'search' => $prefix,
            'membership_package_id' => $annualPro->id,
        ]));
        $annual->assertOk()->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 650021.0
            && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
            && $kpi['successful_member_count'] === 1);

        $bni = $this->adminGet(route('admin.transactions.index', ['search' => $prefix, 'metode' => 'bni_va']));
        $bni->assertOk()->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 750022.0
            && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
            && $kpi['successful_member_count'] === 1);

        $query = [
            'search' => $prefix,
            'membership_package_id' => $annualPro->id,
            'metode' => 'bni_va',
        ];
        $combined = $this->adminGet(route('admin.transactions.index', $query));
        $combined->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->perPage() === 5
                && $transactions->count() === 5
                && $transactions->total() === 9)
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 350018.0
                && $kpi['revenue_success_count'] === 7
                && $kpi['average_transaction_value'] === 50002.57142857143
                && $kpi['average_transaction_label'] === 'Rp 50.003'
                && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
                && $kpi['successful_member_count'] === 1
                && $kpi['successful_member_caption'] === 'Member unik dengan transaksi sukses')
            ->assertSeeText('Rp 350.018')
            ->assertSee('membership_package_id='.$annualPro->id, false)
            ->assertSee('metode=bni_va', false)
            ->assertSee('search='.urlencode($prefix), false)
            ->assertSeeText('Memuat transaksi...');

        $this->adminGet(route('admin.transactions.index', $query + ['page' => 2]))
            ->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->currentPage() === 2
                && $transactions->count() === 4)
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 350018.0
                && $kpi['successful_member_count'] === 1);

        $export = $this->withSession(['admin_user_id' => $this->admin->id])
            ->get(route('admin.transactions.export-ledger', $query));
        $workbook = $this->loadWorkbook($export->streamedContent());
        $summary = $workbook->getSheetByName('Ringkasan');
        $this->assertSame(9, $summary->getCell('B3')->getValue());
        $this->assertSame(7, $summary->getCell('B4')->getValue());
        $this->assertSame(7000.0, $summary->getCell('B7')->getValue());
        $this->assertSame(357018.0, $summary->getCell('B8')->getValue());
        $this->assertSame(350018.0, $summary->getCell('B9')->getValue());
        $workbook->disconnectWorksheets();

        $empty = $this->adminGet(route('admin.transactions.index', [
            'search' => $prefix,
            'membership_package_id' => $annualPro->id,
            'metode' => 'mandiri_va',
        ]));
        $empty->assertOk()->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_label'] === 'Rp 0'
            && $kpi['revenue_value'] === 0.0
            && $kpi['average_transaction_value'] === 0.0
            && $kpi['average_transaction_label'] === 'Rp 0'
            && $kpi['average_transaction_caption'] === 'Belum ada transaksi sukses'
            && $kpi['revenue_caption'] === 'Seluruh transaksi Membership sukses'
            && $kpi['successful_member_count'] === 0
            && $kpi['successful_member_caption'] === 'Belum ada member sesuai filter');
        $this->assertNotSame($combined->viewData('kpi')['revenue_value'], $empty->viewData('kpi')['revenue_value']);
    }

    public function test_member_transaction_card_counts_unique_successful_members_only(): void
    {
        $emptyPlan = MembershipPlan::create([
            'name' => 'Empty Revenue Membership',
            'slug' => 'empty-revenue-'.uniqid(),
            'description' => 'Empty revenue fixture',
            'price' => 100000,
            'duration_days' => 30,
            'billing_period' => 'monthly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        $pending = $this->createTransaction(88, 'qris');
        $pending->update(['membership_plan_id' => $emptyPlan->id, 'status' => 'pending', 'paid_at' => null]);

        $this->adminGet(route('admin.transactions.index', [
            'membership_package_id' => $emptyPlan->id,
            'metode' => 'qris',
        ]))->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['successful_member_count'] === 0
                && $kpi['successful_member_caption'] === 'Belum ada member sesuai filter');

        $legacy = $this->createKpiTransaction('LEGACY-NO-FEE', 'completed', 7000000, now()->toDateTimeString(), false);
        $legacy->update(['membership_plan_id' => $emptyPlan->id]);

        $this->adminGet(route('admin.transactions.index', [
            'search' => 'LEGACY-NO-FEE',
            'membership_package_id' => $emptyPlan->id,
        ]))->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['successful_member_count'] === 1
                && $kpi['successful_member_caption'] === 'Member unik dengan transaksi sukses')
            ->assertSeeText('Member Bertransaksi');

        $secondMember = MemberProfile::create([
            'user_id' => $this->createUser('member', 'Second Transaction Member')->id,
            'member_code' => 'SECOND-TX-'.uniqid(),
            'joined_at' => now(),
        ]);
        foreach ([$this->member, $this->member, $secondMember] as $index => $member) {
            Transaction::create([
                'member_profile_id' => $member->id,
                'membership_plan_id' => $emptyPlan->id,
                'reference_code' => 'UNIQUE-MEMBER-'.($index + 1).'-'.uniqid(),
                'title' => 'Unique member count fixture',
                'payment_method' => 'qris',
                'amount' => 100000,
                'fee' => 2500,
                'total_payment' => 102500,
                'status' => 'completed',
                'paid_at' => now(),
            ]);
        }

        $this->adminGet(route('admin.transactions.index', [
            'search' => 'UNIQUE-MEMBER-',
            'membership_package_id' => $emptyPlan->id,
        ]))->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->total() === 3)
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['successful_member_count'] === 2);
    }

    public function test_all_dates_membership_revenue_includes_successful_transaction_from_previous_month(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-07-24 21:20:30', 'Asia/Jakarta'));
        $annualPro = MembershipPlan::create([
            'name' => 'Annual Pro',
            'slug' => 'annual-pro-revenue-'.uniqid(),
            'description' => 'Annual package fixture',
            'price' => 1900000,
            'duration_days' => 365,
            'billing_period' => 'yearly',
            'features_json' => ['Gym access'],
            'is_active' => true,
        ]);
        $transaction = Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $annualPro->id,
            'reference_code' => 'ANNUAL-PRO-'.uniqid(),
            'title' => 'Annual Pro Membership',
            'payment_method' => 'qris',
            'amount' => 1900000,
            'fee' => 100000,
            'total_payment' => 2000000,
            'status' => 'completed',
            'paid_at' => '2026-06-22 10:00:00',
            'created_at' => '2026-06-22 10:00:00',
            'updated_at' => '2026-06-22 10:00:00',
        ]);

        $response = $this->adminGet(route('admin.transactions.index', [
            'membership_package_id' => $annualPro->id,
        ]));
        $response->assertOk()
            ->assertSee('title="'.$transaction->reference_code.'"', false)
            ->assertViewHas('transactions', fn ($transactions) => $transactions->total() === 1)
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['successful_member_count'] === 1);

        $this->adminGet(route('admin.transactions.index', [
            'membership_package_id' => $annualPro->id,
            'date' => 'month',
        ]))->assertOk()
            ->assertViewHas('transactions', fn ($transactions) => $transactions->total() === 0)
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['successful_member_count'] === 0
                && $kpi['successful_member_caption'] === 'Belum ada member sesuai filter');
    }

    public function test_revenue_cards_exclude_every_non_success_transaction_status(): void
    {
        $this->travelTo(CarbonImmutable::parse('2037-05-20 12:00:00', 'Asia/Jakarta'));
        $success = $this->createFinancialStatusTransaction('completed', 299000, 10000);
        $paid = $this->createFinancialStatusTransaction('paid', 301000, 10000);
        foreach (['pending', 'failed', 'expired', 'cancelled', 'waiting', 'waiting_payment'] as $status) {
            $this->createFinancialStatusTransaction($status, 9000000, 500000);
        }

        $response = $this->adminGet(route('admin.transactions.index', [
            'membership_package_id' => $this->plan->id,
        ]));
        $response->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_label'] === 'Rp 600.000'
                && $kpi['average_transaction_value'] === 300000.0
                && $kpi['average_transaction_label'] === 'Rp 300.000'
                && $kpi['successful_member_count'] === 1);

        $this->assertSame(299000.0, (float) $success->total_payment - (float) $success->fee);
        $this->assertSame(301000.0, (float) $paid->total_payment - (float) $paid->fee);
    }

    public function test_average_transaction_uses_only_successful_membership_net_amounts(): void
    {
        foreach ([282666, 282667, 282667] as $index => $net) {
            $this->createFinancialStatusTransaction(
                $index === 1 ? 'paid' : 'completed',
                $net,
                2500
            );
        }
        foreach (['pending', 'failed', 'expired', 'cancelled', 'waiting_payment'] as $status) {
            $this->createFinancialStatusTransaction($status, 9000000, 500000);
        }
        $this->createPtTransaction('AVERAGE-PT-EXCLUDED', 'qris', 99000000, 'completed', now()->toDateTimeString());

        $response = $this->adminGet(route('admin.transactions.index', [
            'membership_package_id' => $this->plan->id,
        ]));
        $response->assertOk()
            ->assertViewHas('kpi', fn (array $kpi) => $kpi['revenue_value'] === 848000.0
                && $kpi['revenue_success_count'] === 3
                && $kpi['average_transaction_value'] === 282666.6666666667
                && $kpi['average_transaction_label'] === 'Rp 282.667'
                && $kpi['average_transaction_caption'] === 'Dari transaksi membership sukses')
            ->assertSeeText('Rata-rata Transaksi')
            ->assertSeeText('Rp 282.667')
            ->assertDontSeeText('Transaksi Berhasil');
    }

    private function createTransaction(int $index, string $method): Transaction
    {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'reference_code' => 'PRESENTATION-TX-'.$index.'-'.uniqid(),
            'title' => 'Membership Payment',
            'payment_method' => $method,
            'amount' => 100000 + $index,
            'fee' => 2500,
            'total_payment' => 102500 + $index,
            'status' => $index % 2 === 0 ? 'completed' : 'pending',
            'paid_at' => $index % 2 === 0 ? now() : null,
        ]);
    }

    private function createKpiTransaction(
        string $reference,
        string $status,
        float $amount,
        ?string $paidAt,
        bool $hasProviderFee = true
    ): Transaction {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'reference_code' => $reference.'-'.uniqid(),
            'title' => 'KPI Payment',
            'payment_method' => 'qris',
            'amount' => $amount,
            'fee' => $hasProviderFee ? 5000 : null,
            'total_payment' => $hasProviderFee ? $amount + 5000 : null,
            'status' => $status,
            'paid_at' => $paidAt,
        ]);
    }

    private function createPtTransaction(
        string $reference,
        string $method,
        float $amount,
        string $status = 'pending',
        ?string $paidAt = null
    ): Transaction {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => null,
            'reference_code' => $reference.'-'.uniqid(),
            'title' => 'Personal Trainer Payment',
            'payment_method' => $method,
            'amount' => $amount,
            'total_payment' => $amount,
            'status' => $status,
            'paid_at' => $paidAt,
        ]);
    }

    private function createFinancialStatusTransaction(string $status, float $net, float $fee): Transaction
    {
        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $this->plan->id,
            'reference_code' => strtoupper($status).'-FINANCE-'.uniqid(),
            'title' => 'Financial status audit',
            'payment_method' => 'qris',
            'amount' => $net,
            'fee' => $fee,
            'total_payment' => $net + $fee,
            'status' => $status,
            'paid_at' => now(),
        ]);
    }

    private function createFilteredRevenueTransaction(
        string $reference,
        MembershipPlan $plan,
        string $method,
        string $status,
        float $net,
        ?string $paidAt
    ): Transaction {
        $fee = 1000;

        return Transaction::create([
            'member_profile_id' => $this->member->id,
            'membership_plan_id' => $plan->id,
            'reference_code' => $reference,
            'title' => 'Filtered membership revenue',
            'payment_method' => $method,
            'amount' => $net,
            'fee' => $fee,
            'total_payment' => $net + $fee,
            'status' => $status,
            'paid_at' => $paidAt,
            'created_at' => $paidAt ?? '2036-07-25 10:00:00',
            'updated_at' => $paidAt ?? '2036-07-25 10:00:00',
        ]);
    }

    private function createUser(string $roleName, string $name): User
    {
        $role = Role::firstOrCreate(['name' => $roleName]);

        return User::create([
            'role_id' => $role->id,
            'name' => $name,
            'email' => uniqid($roleName.'_tx_', true).'@example.test',
            'password' => 'password123',
            'status' => 'active',
        ]);
    }

    private function adminGet(string $url)
    {
        return $this->withSession(['admin_user_id' => $this->admin->id])->get($url);
    }

    private function loadWorkbook(string $content): Spreadsheet
    {
        $path = tempnam(sys_get_temp_dir(), 'egggym-xlsx-');
        file_put_contents($path, $content);

        try {
            return IOFactory::load($path);
        } finally {
            unlink($path);
        }
    }
}
