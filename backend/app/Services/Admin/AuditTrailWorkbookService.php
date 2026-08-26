<?php

namespace App\Services\Admin;

use App\Http\Controllers\Web\Admin\AuditTrailController;
use App\Models\ActivityLog;
use App\Support\AuditTrailFormatter;
use Illuminate\Support\Collection;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\Shared\Date;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;

class AuditTrailWorkbookService
{
    public function build(Collection $logs, array $filters): Spreadsheet
    {
        $spreadsheet = new Spreadsheet;
        $this->buildAuditSheet($spreadsheet, $logs);
        $this->buildSummarySheet($spreadsheet, $logs, $filters);
        $spreadsheet->setActiveSheetIndex(0);

        return $spreadsheet;
    }

    private function buildSummarySheet(Spreadsheet $spreadsheet, Collection $logs, array $filters): void
    {
        $sheet = $spreadsheet->createSheet();
        $sheet->setTitle('Ringkasan');
        $categoryCounts = collect(AuditTrailController::CATEGORY_LABELS)
            ->except('all')
            ->mapWithKeys(fn (string $label, string $key) => [
                $label => $logs->filter(fn (ActivityLog $log) => AuditTrailController::categoryFor($log) === $key)->count(),
            ]);
        $rows = [
            ['Ringkasan Export Audit Trail EGGGYM', null],
            ['Tanggal Export', $filters['exported_at']],
            ['Rentang Tanggal Aktif', $filters['date_label']],
            ['Kategori Aktivitas Aktif', $filters['category_label']],
            ['Pelaku Aktif', $filters['actor_label']],
            ['Keyword Pencarian Aktif', $filters['search'] !== '' ? $filters['search'] : 'Tidak ada'],
            ['Total Aktivitas Diekspor', $logs->count()],
        ];
        foreach ($categoryCounts as $label => $count) {
            $rows[] = [$label, $count];
        }
        $sheet->fromArray($rows, null, 'A1', true);
        $sheet->mergeCells('A1:B1');
        $sheet->getStyle('A1:B1')->applyFromArray($this->headerStyle());
        $sheet->getStyle('A2:A12')->getFont()->setBold(true);
        $sheet->getCell('B2')->setValue(Date::dateTimeToExcel($filters['exported_at']));
        $sheet->getStyle('B2')->getNumberFormat()->setFormatCode('dd mmmm yyyy hh:mm:ss');
        $sheet->getColumnDimension('A')->setWidth(34);
        $sheet->getColumnDimension('B')->setWidth(42);
        $sheet->getStyle('A1:B12')->getAlignment()->setVertical(Alignment::VERTICAL_TOP);
        $sheet->freezePane('A2');
    }

    private function buildAuditSheet(Spreadsheet $spreadsheet, Collection $logs): void
    {
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Audit Trail');
        $sheet->fromArray([
            'Waktu',
            'Pelaku',
            'Role',
            'Jenis Aktivitas',
            'Aktivitas',
            'Objek Terdampak',
            'Hasil',
            'Sumber',
            'Ringkasan Perubahan',
        ], null, 'A1');
        $sheet->getStyle('A1:I1')->applyFromArray($this->headerStyle());

        foreach ($logs->values() as $index => $log) {
            $row = $index + 2;
            $sheet->setCellValue("A{$row}", Date::dateTimeToExcel($log->created_at));
            $sheet->setCellValueExplicit("B{$row}", $log->user?->name ?? 'Sistem', DataType::TYPE_STRING);
            $sheet->setCellValueExplicit("C{$row}", AuditTrailController::resolveRole($log), DataType::TYPE_STRING);
            $sheet->setCellValueExplicit(
                "D{$row}",
                AuditTrailController::CATEGORY_LABELS[AuditTrailController::categoryFor($log)] ?? '-',
                DataType::TYPE_STRING
            );
            $sheet->setCellValueExplicit("E{$row}", $log->description ?: $log->action, DataType::TYPE_STRING);
            $sheet->setCellValueExplicit("F{$row}", AuditTrailController::resolveTarget($log), DataType::TYPE_STRING);
            $sheet->setCellValueExplicit("G{$row}", AuditTrailController::resolveStatus($log)['label'], DataType::TYPE_STRING);
            $sheet->setCellValueExplicit("H{$row}", AuditTrailController::resolveSource($log), DataType::TYPE_STRING);
            $sheet->setCellValueExplicit("I{$row}", $this->changeSummary($log), DataType::TYPE_STRING);
        }

        $lastRow = max(1, $logs->count() + 1);
        $sheet->freezePane('A2');
        $sheet->setAutoFilter("A1:I{$lastRow}");
        $sheet->getStyle("A2:A{$lastRow}")->getNumberFormat()->setFormatCode('dd mmmm yyyy hh:mm:ss');
        $sheet->getStyle("A1:I{$lastRow}")->getAlignment()
            ->setVertical(Alignment::VERTICAL_TOP)
            ->setWrapText(true);
        $sheet->getStyle("A1:I{$lastRow}")->getBorders()->getAllBorders()
            ->setBorderStyle(Border::BORDER_THIN)
            ->setColor(new \PhpOffice\PhpSpreadsheet\Style\Color('FFD1D5DB'));
        foreach (['A' => 24, 'B' => 22, 'C' => 16, 'D' => 22, 'E' => 42, 'F' => 42, 'G' => 16, 'H' => 22, 'I' => 52] as $column => $width) {
            $sheet->getColumnDimension($column)->setWidth($width);
        }
        for ($row = 2; $row <= $lastRow; $row++) {
            $sheet->getRowDimension($row)->setRowHeight(-1);
        }
    }

    private function changeSummary(ActivityLog $log): string
    {
        $details = AuditTrailFormatter::details($log);
        if ($details === null) {
            return '';
        }

        return collect($details['rows'])->map(function (array $row) use ($details): string {
            return match ($details['mode']) {
                'create' => "{$row['label']}: {$row['new']}",
                'delete' => "{$row['label']}: {$row['old']}",
                default => "{$row['label']}: {$row['old']} → {$row['new']}",
            };
        })->implode("\n");
    }

    private function headerStyle(): array
    {
        return [
            'font' => ['bold' => true, 'color' => ['rgb' => '131313']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => 'FACC15']],
            'alignment' => [
                'horizontal' => Alignment::HORIZONTAL_CENTER,
                'vertical' => Alignment::VERTICAL_CENTER,
            ],
            'borders' => [
                'allBorders' => [
                    'borderStyle' => Border::BORDER_THIN,
                    'color' => ['rgb' => 'A3A3A3'],
                ],
            ],
        ];
    }
}
