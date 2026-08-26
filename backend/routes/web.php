<?php

use App\Http\Controllers\Web\Admin\AdminAccountController;
use App\Http\Controllers\Web\Admin\AdminAuthController;
use App\Http\Controllers\Web\Admin\AdminDashboardController;
use App\Http\Controllers\Web\Admin\AuditTrailController;
use App\Http\Controllers\Web\Admin\BookingMonitorController;
use App\Http\Controllers\Web\Admin\EquipmentController;
use App\Http\Controllers\Web\Admin\GymOperationHourController;
use App\Http\Controllers\Web\Admin\MemberMonitorController;
use App\Http\Controllers\Web\Admin\MemberPhysicalProgressMonitorController;
use App\Http\Controllers\Web\Admin\MembershipPlanController;
use App\Http\Controllers\Web\Admin\NotificationController;
use App\Http\Controllers\Web\Admin\ProgramMonitorController;
use App\Http\Controllers\Web\Admin\ReportController;
use App\Http\Controllers\Web\Admin\SettingsController;
use App\Http\Controllers\Web\Admin\TrainerProfileController;
use App\Http\Controllers\Web\Admin\TransactionMonitorController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});

Route::prefix('admin')->group(function () {
    Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
    Route::post('/login', [AdminAuthController::class, 'login'])->name('admin.login.submit');

    Route::middleware('admin.session')->group(function () {
        Route::post('/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');
        Route::get('/', [AdminDashboardController::class, 'index'])->name('admin.dashboard');
        Route::middleware('admin.owner')->group(function () {
            Route::get('admin-accounts', [AdminAccountController::class, 'index'])->name('admin.admin-accounts.index');
            Route::get('admin-accounts/create', [AdminAccountController::class, 'create'])->name('admin.admin-accounts.create');
            Route::post('admin-accounts', [AdminAccountController::class, 'store'])->name('admin.admin-accounts.store');
            Route::get('admin-accounts/{adminAccount}/edit', [AdminAccountController::class, 'edit'])->name('admin.admin-accounts.edit');
            Route::put('admin-accounts/{adminAccount}', [AdminAccountController::class, 'update'])->name('admin.admin-accounts.update');
            Route::patch('admin-accounts/{adminAccount}/toggle-status', [AdminAccountController::class, 'toggleStatus'])->name('admin.admin-accounts.toggle-status');
            Route::put('settings/identity', [SettingsController::class, 'updateIdentity'])->name('admin.settings.identity.update');
            Route::put('settings/branding', [SettingsController::class, 'updateBranding'])->name('admin.settings.branding.update');
            Route::delete('settings/branding/logo', [SettingsController::class, 'removeLogo'])->name('admin.settings.branding.logo.destroy');
            Route::put('settings/contact', [SettingsController::class, 'updateContact'])->name('admin.settings.contact.update');
            Route::put('settings/payment-methods', [SettingsController::class, 'updatePaymentMethods'])->name('admin.settings.payment-methods.update');
            Route::get('operation-hours/{operationHour}/edit', [GymOperationHourController::class, 'edit'])
                ->name('admin.operation-hours.edit');
            Route::put('operation-hours/{operationHour}', [GymOperationHourController::class, 'update'])
                ->name('admin.operation-hours.update');
        });
        Route::resource('membership-plans', MembershipPlanController::class)
            ->names('admin.membership-plans')
            ->only(['index', 'store', 'update', 'destroy']);
        Route::resource('trainer-profiles', TrainerProfileController::class)
            ->names('admin.trainer-profiles')
            ->only(['index', 'create', 'store', 'show', 'edit', 'update', 'destroy']);
        Route::get('trainer-profiles/{trainerProfile}/schedule', [TrainerProfileController::class, 'schedule'])
            ->name('admin.trainer-profiles.schedule');
        Route::patch('trainer-profiles/{trainerProfile}/toggle-status', [TrainerProfileController::class, 'toggleStatus'])
            ->name('admin.trainer-profiles.toggle-status');
        Route::get('members', [MemberMonitorController::class, 'index'])
            ->name('admin.members.index');
        Route::get('members/create', [MemberMonitorController::class, 'create'])
            ->name('admin.members.create');
        Route::post('members', [MemberMonitorController::class, 'store'])
            ->name('admin.members.store');
        Route::get('members/{member}/edit', [MemberMonitorController::class, 'edit'])
            ->name('admin.members.edit');
        Route::put('members/{member}', [MemberMonitorController::class, 'update'])
            ->name('admin.members.update');
        Route::put('members/{member}/password', [MemberMonitorController::class, 'resetPassword'])
            ->name('admin.members.password.update');
        Route::patch('members/{member}/toggle-status', [MemberMonitorController::class, 'toggleStatus'])
            ->name('admin.members.toggle-status');
        Route::delete('members/{member}', [MemberMonitorController::class, 'destroy'])
            ->name('admin.members.destroy');
        Route::get('member-progress', [MemberPhysicalProgressMonitorController::class, 'index'])
            ->name('admin.member-progress.index');
        Route::get('programs', [ProgramMonitorController::class, 'index'])
            ->name('admin.programs.index');
        Route::get('bookings', [BookingMonitorController::class, 'index'])
            ->name('admin.bookings.index');
        Route::get('bookings/live-progress', [BookingMonitorController::class, 'liveProgress'])
            ->name('admin.bookings.live-progress');
        Route::patch('bookings/{booking}/confirm', [BookingMonitorController::class, 'confirm'])
            ->name('admin.bookings.confirm');
        Route::patch('bookings/{booking}/reject', [BookingMonitorController::class, 'reject'])
            ->name('admin.bookings.reject');
        Route::patch('bookings/{booking}/reassign-trainer', [BookingMonitorController::class, 'reassignTrainer'])
            ->name('admin.bookings.reassign-trainer');
        Route::get('transactions', [TransactionMonitorController::class, 'index'])
            ->name('admin.transactions.index');
        Route::get('transactions/export-ledger', [TransactionMonitorController::class, 'exportLedger'])
            ->name('admin.transactions.export-ledger');
        Route::post('transactions/{transaction}/simulate-payment', [TransactionMonitorController::class, 'simulatePayment'])
            ->name('admin.transactions.simulate-payment');
        Route::get('operation-hours', [GymOperationHourController::class, 'index'])
            ->name('admin.operation-hours.index');
        Route::resource('equipments', EquipmentController::class)
            ->names('admin.equipments')
            ->except(['show']);
        Route::get('notifications', [NotificationController::class, 'index'])
            ->name('admin.notifications.index');
        Route::get('my-notifications', [NotificationController::class, 'inbox'])
            ->name('admin.notifications.inbox');
        Route::post('my-notifications/read-all', [NotificationController::class, 'markAllAsRead'])
            ->name('admin.notifications.read-all');
        Route::post('my-notifications/{id}/read', [NotificationController::class, 'markAsRead'])
            ->name('admin.notifications.read');
        Route::get('notifications/create', [NotificationController::class, 'create'])
            ->name('admin.notifications.create');
        Route::post('notifications', [NotificationController::class, 'store'])
            ->name('admin.notifications.store');
        Route::get('notifications/broadcast', [NotificationController::class, 'broadcastForm'])
            ->name('admin.notifications.broadcast');
        Route::post('notifications/broadcast', [NotificationController::class, 'broadcast'])
            ->name('admin.notifications.broadcast.send');
        Route::delete('notifications/{notification}', [NotificationController::class, 'destroy'])
            ->name('admin.notifications.destroy');
        Route::get('audit-trail', [AuditTrailController::class, 'index'])
            ->name('admin.audit-trail.index');
        Route::get('audit-trail/export', [AuditTrailController::class, 'export'])
            ->name('admin.audit-trail.export');
        Route::get('reports', [ReportController::class, 'index'])
            ->name('admin.reports.index');
        Route::get('settings', [SettingsController::class, 'index'])
            ->name('admin.settings.index');
    });
});
