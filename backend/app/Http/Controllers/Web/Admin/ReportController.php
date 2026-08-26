<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Services\Admin\OperationalReportService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(
        private readonly OperationalReportService $operationalReport,
    ) {}

    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $report = $this->operationalReport->build($search);

        return view('admin.reports.index', [
            ...$report,
            'search' => $search,
        ]);
    }
}
