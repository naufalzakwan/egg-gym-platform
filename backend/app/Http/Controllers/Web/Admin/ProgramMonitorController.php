<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\TrainingProgram;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;

class ProgramMonitorController extends Controller
{
    public function index(Request $request): View
    {
        $programs = TrainingProgram::query()
            ->with([
                'trainerProfile.user',
                'memberProfile.user',
                'booking',
                'sessions',
            ])
            ->withCount('sessions')
            ->when($request->filled('status'), function ($query) use ($request) {
                $query->where('status', trim((string) $request->query('status')));
            })
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = trim((string) $request->query('search'));

                $query->where(function ($innerQuery) use ($search) {
                    $innerQuery->where('title', 'like', '%' . $search . '%')
                        ->orWhere('goal', 'like', '%' . $search . '%')
                        ->orWhere('description', 'like', '%' . $search . '%')
                        ->orWhereHas('memberProfile.user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%' . $search . '%')
                                ->orWhere('email', 'like', '%' . $search . '%');
                        })
                        ->orWhereHas('trainerProfile.user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', '%' . $search . '%')
                                ->orWhere('email', 'like', '%' . $search . '%');
                        });
                });
            })
            ->latest('created_at')
            ->paginate(12)
            ->withQueryString();

        return view('admin.programs.index', [
            'programs' => $programs,
            'search' => $request->query('search'),
            'status' => $request->query('status'),
        ]);
    }
}
