<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Services\ActivityLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class AdminAccountController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));

        return view('admin.admin-accounts.index', [
            'admins' => User::query()
                ->with('role')
                ->whereHas('role', fn ($query) => $query->where('name', 'admin'))
                ->when($search !== '', fn ($query) => $query->where(function ($inner) use ($search) {
                    $inner->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('status', 'like', "%{$search}%");
                }))
                ->orderByDesc('is_admin_owner')
                ->orderBy('name')
                ->paginate(10)
                ->withQueryString(),
            'search' => $search,
        ]);
    }

    public function create(): View
    {
        return view('admin.admin-accounts.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'status' => ['required', Rule::in(['active', 'inactive'])],
        ]);
        $roleId = Role::query()->where('name', 'admin')->value('id');
        abort_if(! $roleId, 422, 'Role Admin belum tersedia.');

        $admin = User::create([
            'role_id' => $roleId,
            'name' => $validated['name'],
            'email' => strtolower($validated['email']),
            'password' => $validated['password'],
            'status' => $validated['status'],
            'is_admin_owner' => false,
        ]);

        ActivityLogger::log(
            action: 'admin_account_created',
            model: $admin,
            newData: $this->safeAccountData($admin),
            description: "Admin {$request->user()->name} membuat akun Admin {$admin->name}",
        );

        return redirect()->route('admin.admin-accounts.index')->with('success', 'Akun Admin berhasil dibuat.');
    }

    public function edit(User $adminAccount): View
    {
        $this->ensureAdmin($adminAccount);

        return view('admin.admin-accounts.edit', ['adminAccount' => $adminAccount]);
    }

    public function update(Request $request, User $adminAccount): RedirectResponse
    {
        $this->ensureAdmin($adminAccount);
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($adminAccount->id)],
        ]);
        $oldData = $this->safeAccountData($adminAccount);
        $adminAccount->update([
            'name' => $validated['name'],
            'email' => strtolower($validated['email']),
        ]);

        ActivityLogger::log(
            action: 'admin_account_updated',
            model: $adminAccount,
            oldData: $oldData,
            newData: $this->safeAccountData($adminAccount->fresh()),
            description: "Admin {$request->user()->name} memperbarui akun Admin {$adminAccount->name}",
        );

        return redirect()->route('admin.admin-accounts.index')->with('success', 'Data akun Admin berhasil diperbarui.');
    }

    public function toggleStatus(Request $request, User $adminAccount): RedirectResponse
    {
        $this->ensureAdmin($adminAccount);
        $nextStatus = $adminAccount->status === 'active' ? 'inactive' : 'active';
        if ($nextStatus === 'inactive') {
            abort_if($adminAccount->is($request->user()), 422, 'Anda tidak dapat menonaktifkan akun sendiri.');
            if ($adminAccount->is_admin_owner) {
                $activeOwnerCount = User::query()
                    ->where('is_admin_owner', true)
                    ->where('status', 'active')
                    ->count();
                abort_if($activeOwnerCount <= 1, 422, 'Minimal satu Admin utama harus tetap aktif.');
            }
        }

        $oldData = $this->safeAccountData($adminAccount);
        $adminAccount->update(['status' => $nextStatus]);
        $action = $nextStatus === 'active' ? 'admin_account_activated' : 'admin_account_deactivated';
        $verb = $nextStatus === 'active' ? 'mengaktifkan' : 'menonaktifkan';
        ActivityLogger::log(
            action: $action,
            model: $adminAccount,
            oldData: $oldData,
            newData: $this->safeAccountData($adminAccount->fresh()),
            description: "Admin {$request->user()->name} {$verb} akun Admin {$adminAccount->name}",
        );

        return back()->with('success', "Akun Admin berhasil {$verb}.");
    }

    private function ensureAdmin(User $user): void
    {
        abort_unless($user->role()->where('name', 'admin')->exists(), 404);
    }

    private function safeAccountData(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'status' => $user->status,
            'is_admin_owner' => $user->is_admin_owner,
        ];
    }
}
