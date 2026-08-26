<?php

namespace App\Providers;

use App\Models\GymSetting;
use App\Models\UserNotification;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        View::composer(['admin.layouts.app', 'admin.auth.login'], function ($view) {
            $settings = Schema::hasTable('gym_settings') ? GymSetting::query()->first() : null;
            $view->with('appBranding', [
                'name' => $settings?->brand_name ?: 'EGGGYM',
                'tagline' => $settings?->tagline ?: 'Your Gym, Smarter',
                'logo_path' => $settings?->logo_path,
                'logo_version' => $settings?->logo_version ?? 1,
            ]);
            $adminUserId = session('admin_user_id');
            $view->with('adminUnreadNotificationCount', $adminUserId
                ? UserNotification::query()->where('user_id', $adminUserId)->where('is_read', false)->count()
                : 0);
            $view->with('adminLatestNotifications', $adminUserId
                ? UserNotification::query()
                    ->where('user_id', $adminUserId)
                    ->orderByRaw("CASE WHEN priority = 'high' THEN 0 ELSE 1 END")
                    ->orderBy('is_read')
                    ->latest('sent_at')
                    ->limit(5)
                    ->get()
                : collect());
        });
    }
}
