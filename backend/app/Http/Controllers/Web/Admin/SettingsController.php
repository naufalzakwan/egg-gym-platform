<?php

namespace App\Http\Controllers\Web\Admin;

use App\Http\Controllers\Controller;
use App\Models\Equipment;
use App\Models\GymOperationHour;
use App\Models\GymSetting;
use App\Models\MemberProfile;
use App\Models\MembershipPaymentMethod;
use App\Models\TrainerProfile;
use App\Models\User;
use App\Services\PublicSettingsService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class SettingsController extends Controller
{
    public function index(): View
    {
        $admin = auth()->user();
        $adminAccountMetrics = null;
        if ($admin?->is_admin_owner) {
            $adminAccounts = User::query()
                ->whereHas('role', fn ($query) => $query->where('name', 'admin'));
            $adminAccountMetrics = [
                'total' => (clone $adminAccounts)->count(),
                'active' => (clone $adminAccounts)->where('status', 'active')->count(),
                'inactive' => (clone $adminAccounts)->where('status', 'inactive')->count(),
            ];
        }

        return view('admin.settings.index', [
            'hours' => GymOperationHour::query()->orderBy('day_order')->get(),
            'settings' => GymSetting::current(),
            'paymentMethods' => MembershipPaymentMethod::query()
                ->where('provider', 'pakasir')->orderBy('display_order')->orderBy('id')->get(),
            'admin' => $admin,
            'adminAccountMetrics' => $adminAccountMetrics,
            'metrics' => [
                'total_members' => MemberProfile::query()->count(),
                'total_trainers' => TrainerProfile::query()->count(),
                'total_equipment' => Equipment::query()->count(),
            ],
        ]);
    }

    public function updateIdentity(Request $request, PublicSettingsService $publicSettings): RedirectResponse
    {
        $validated = $request->validate([
            'gym_name' => ['required', 'string', 'max:150'],
            'tagline' => ['nullable', 'string', 'max:180'],
            'address' => ['required', 'string', 'max:2000'],
            'city' => ['required', 'string', 'max:100'],
            'province' => ['required', 'string', 'max:100'],
            'postal_code' => ['nullable', 'string', 'max:12'],
            'maps_url' => ['nullable', 'url', 'max:2048'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
        ]);

        GymSetting::current()->update($validated);
        $publicSettings->forget();

        return back()->with('success', 'Identitas dan lokasi gym berhasil disimpan.');
    }

    public function updateBranding(Request $request, PublicSettingsService $publicSettings): RedirectResponse
    {
        $validated = $request->validate([
            'brand_name' => ['required', 'string', 'max:100'],
            'tagline' => ['nullable', 'string', 'max:180'],
            'logo' => ['nullable', 'file', 'image', 'mimes:png,jpg,jpeg,webp', 'max:4096'],
        ]);
        $settings = GymSetting::current();
        $oldPath = $settings->logo_path;

        if ($request->hasFile('logo')) {
            $validated['logo_path'] = $request->file('logo')->store('branding', 'public');
            $validated['logo_version'] = $settings->logo_version + 1;
        }
        unset($validated['logo']);
        $settings->update($validated);

        if (isset($validated['logo_path']) && $oldPath && ! str_starts_with($oldPath, 'http')) {
            Storage::disk('public')->delete($oldPath);
        }
        $publicSettings->forget();

        return back()->with('success', 'Branding EGGGYM berhasil disimpan.');
    }

    public function removeLogo(PublicSettingsService $publicSettings): RedirectResponse
    {
        $settings = GymSetting::current();
        $oldPath = $settings->logo_path;
        $settings->update(['logo_path' => null, 'logo_version' => $settings->logo_version + 1]);
        if ($oldPath && ! str_starts_with($oldPath, 'http')) {
            Storage::disk('public')->delete($oldPath);
        }
        $publicSettings->forget();

        return back()->with('success', 'Logo dikembalikan ke tampilan default.');
    }

    public function updateContact(Request $request, PublicSettingsService $publicSettings): RedirectResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'whatsapp' => ['required', 'string', 'max:30'],
            'email' => ['required', 'email', 'max:255'],
            'instagram' => ['nullable', 'string', 'max:100'],
        ]);
        GymSetting::current()->update($validated);
        $publicSettings->forget();

        return back()->with('success', 'Kontak gym berhasil disimpan.');
    }

    public function updatePaymentMethods(Request $request, PublicSettingsService $publicSettings): RedirectResponse
    {
        $supportedIds = MembershipPaymentMethod::query()->where('provider', 'pakasir')->pluck('id')->all();
        $validated = $request->validate([
            'methods' => ['required', 'array'],
            'methods.*.id' => ['required', 'integer', Rule::in($supportedIds)],
            'methods.*.display_name' => ['required', 'string', 'max:100'],
            'methods.*.display_order' => ['required', 'integer', 'between:0,10000'],
            'methods.*.is_active' => ['nullable', 'boolean'],
        ]);

        DB::transaction(function () use ($validated) {
            foreach ($validated['methods'] as $method) {
                MembershipPaymentMethod::query()->whereKey($method['id'])->where('provider', 'pakasir')->update([
                    'display_name' => $method['display_name'],
                    'display_order' => $method['display_order'],
                    'is_active' => (bool) ($method['is_active'] ?? false),
                ]);
            }
        });
        $publicSettings->forget();

        return back()->with('success', 'Metode pembayaran Membership berhasil disimpan.');
    }
}
