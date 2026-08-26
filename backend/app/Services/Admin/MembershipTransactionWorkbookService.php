<?php

namespace App\Services\Admin;

use App\Models\Transaction;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\Shared\Date;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class MembershipTransactionWorkbookService
{
    private const FAILURE_STATUSES = ['failed', 'expired', 'cancelled'];

    private const RUPIAH_FORMAT = '[$Rp-421] #,##0';

    public function __construct(
        private readonly MembershipRevenueService $membershipRevenue,
    ) {}

    public function build(Collection $transactions, string $periodLabel): Spreadsheet
    {
        $spreadsheet = new Spreadsheet;
        $this->buildSummarySheet($spreadsheet, $transactions, $periodLabel);
        $this->buildTransactionSheet($spreadsheet, $transactions);
        $spreadsheet->setActiveSheetIndex(0);

        return $spreadsheet;
    }

    private function buildSummarySheet(Spreadsheet $spreadsheet, Collection $transactions, string $periodLabel): void
    {
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Ringkasan');
        $successful = $transactions->filter(fn (Transaction $transaction) => in_array(
            $transaction->status,
            MembershipRevenueService::SUCCESS_STATUSES,
            true
        ));
        $failed = $transactions->filter(fn (Transaction $transaction) => in_array(
            $transaction->status,
            self::FAILURE_STATUSES,
            true
        ));
        $knownNet = $successful->filter(fn (Transaction $transaction) => $this->membershipRevenue->netAmount($transaction) !== null);

        $sheet->fromArray([
            ['Ringkasan Pembukuan Transaksi Membership', null],
            ['Periode Export', $periodLabel],
            ['Jumlah Seluruh Transaksi', $transactions->count()],
            ['Jumlah Transaksi Sukses', $successful->count()],
            ['Jumlah Transaksi Gagal', $failed->count()],
            ['Total Harga Membership Sukses', (float) $successful->sum('amount')],
            ['Total Biaya Layanan Transaksi Sukses', (float) $successful->whereNotNull('fee')->sum('fee')],
            ['Total Dibayar Member untuk Transaksi Sukses', (float) $successful->whereNotNull('total_payment')->sum('total_payment')],
            ['Total Pendapatan Bersih Transaksi Sukses', (float) $knownNet->sum(
                fn (Transaction $transaction) => $this->membershipRevenue->netAmount($transaction)
            )],
            ['Transaksi Sukses Tanpa Data Fee Lengkap', $successful->count() - $knownNet->count()],
        ], null, 'A1', true);

        $sheet->mergeCells('A1:B1');
        $sheet->getStyle('A1:B1')->applyFromArray($this->headerStyle());
        $sheet->getStyle('A2:A10')->getFont()->setBold(true);
        $sheet->getStyle('B6:B9')->getNumberFormat()->setFormatCode(self::RUPIAH_FORMAT);
        $sheet->getColumnDimension('A')->setAutoSize(true);
        $sheet->getColumnDimension('B')->setAutoSize(true);
        $sheet->freezePane('A2');
    }

    private function buildTransactionSheet(Spreadsheet $spreadsheet, Collection $transactions): void
    {
        $sheet = $spreadsheet->createSheet();
        $sheet->setTitle('Transaksi Membership');
        $sheet->fromArray([
            'Kode Transaksi',
            'Member',
            'Membership',
            'Metode Pembayaran',
            'Harga Membership',
            'Biaya Layanan',
            'Total Dibayar Member',
            'Pendapatan Bersih',
            'Tanggal',
            'Waktu',
            'Status',
        ], null, 'A1');
        $sheet->getStyle('A1:K1')->applyFromArray($this->headerStyle());

        foreach ($transactions->values() as $index => $transaction) {
            $row = $index + 2;
            $transactionAt = $transaction->paid_at ?? $transaction->created_at;
            $sheet->setCellValueExplicit("A{$row}", (string) $transaction->reference_code, DataType::TYPE_STRING);
            $sheet->setCellValue("B{$row}", $transaction->memberProfile?->user?->name ?? '');
            $sheet->setCellValue("C{$row}", $transaction->membershipPlan?->name ?? '');
            $sheet->setCellValue("D{$row}", $this->methodLabel($transaction->payment_method));
            $sheet->setCellValue("E{$row}", (float) $transaction->amount);
            $this->setNullableNumber($sheet, "F{$row}", $transaction->fee);
            $this->setNullableNumber($sheet, "G{$row}", $transaction->total_payment);
            $this->setNullableNumber($sheet, "H{$row}", $this->membershipRevenue->netAmount($transaction));
            $this->setDateAndTime($sheet, $row, $transactionAt);
            $sheet->setCellValueExplicit("K{$row}", $this->statusLabel($transaction->status), DataType::TYPE_STRING);
        }

        $lastRow = max(1, $transactions->count() + 1);
        $sheet->freezePane('A2');
        $sheet->setAutoFilter("A1:K{$lastRow}");
        $sheet->getStyle("E2:H{$lastRow}")->getNumberFormat()->setFormatCode(self::RUPIAH_FORMAT);
        $sheet->getStyle("I2:I{$lastRow}")->getNumberFormat()->setFormatCode('dd mmmm yyyy');
        $sheet->getStyle("J2:J{$lastRow}")->getNumberFormat()->setFormatCode('hh:mm');
        $sheet->getStyle("A1:K{$lastRow}")->getAlignment()->setVertical(Alignment::VERTICAL_CENTER);
        foreach (range('A', 'K') as $column) {
            $sheet->getColumnDimension($column)->setAutoSize(true);
        }
    }

    private function setNullableNumber($sheet, string $coordinate, mixed $value): void
    {
        if ($value !== null) {
            $sheet->setCellValue($coordinate, (float) $value);
        }
    }

    private function setDateAndTime($sheet, int $row, ?CarbonInterface $transactionAt): void
    {
        if ($transactionAt === null) {
            return;
        }

        $excelDateTime = Date::dateTimeToExcel($transactionAt);
        $sheet->setCellValue("I{$row}", floor($excelDateTime));
        $sheet->setCellValue("J{$row}", $excelDateTime - floor($excelDateTime));
    }

    private function headerStyle(): array
    {
        return [
            'font' => ['bold' => true, 'color' => ['rgb' => '131313']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => 'FACC15']],
            'alignment' => ['horizontal' => Alignment::HORIZONTAL_CENTER],
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
            null, '' => '',
            default => strtoupper(str_replace('_', ' ', $method)),
        };
    }

    private function statusLabel(?string $status): string
    {
        if (in_array($status, MembershipRevenueService::SUCCESS_STATUSES, true)) {
            return 'Sukses';
        }

        return in_array($status, ['pending', 'waiting', 'waiting_payment'], true) ? 'Pending' : 'Gagal';
    }
}
