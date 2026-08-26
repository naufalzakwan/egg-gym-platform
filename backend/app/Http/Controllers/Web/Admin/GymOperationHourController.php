<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\GymOperationHour;
use App\Services\PublicSettingsService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class GymOperationHourController extends Controller
{
    public function index(): View
    {
        $hours = GymOperationHour::query()
            ->orderBy('day_order')
            ->get();

        return view('admin.operation-hours.index', [
            'hours' => $hours,
        ]);
    }

    public function edit(GymOperationHour $operationHour): View
    {
        return view('admin.operation-hours.form', [
            'hour' => $operationHour,
            'pageTitle' => 'Edit Operation Hour',
            'submitLabel' => 'Update Operation Hour',
            'action' => route('admin.operation-hours.update', $operationHour),
        ]);
    }

    public function update(Request $request, GymOperationHour $operationHour, PublicSettingsService $publicSettings): RedirectResponse
    {
        $validated = $request->validate([
            'day_name' => ['required', 'string', 'max:20'],
            'day_order' => ['required', 'integer', 'min:1', 'max:7', 'unique:gym_operation_hours,day_order,'.$operationHour->id],
            'open_time' => ['nullable', 'date_format:H:i'],
            'close_time' => ['nullable', 'date_format:H:i'],
            'is_closed' => ['nullable', 'boolean'],
        ]);

        $isClosed = (bool) ($validated['is_closed'] ?? false);

        $operationHour->update([
            'day_name' => trim((string) $validated['day_name']),
            'day_order' => (int) $validated['day_order'],
            'open_time' => $isClosed ? null : ($validated['open_time'] ?? null),
            'close_time' => $isClosed ? null : ($validated['close_time'] ?? null),
            'is_closed' => $isClosed,
        ]);
        $publicSettings->forget();

        return redirect()
            ->route('admin.operation-hours.index')
            ->with('success', 'Jam operasional berhasil diperbarui.');
    }
}
