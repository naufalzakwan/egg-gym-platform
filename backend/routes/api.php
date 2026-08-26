<?php

use App\Http\Controllers\Api\V1\Auth\AuthController;
use App\Http\Controllers\Api\V1\Auth\DeviceTokenController;
use App\Http\Controllers\Api\V1\Member\MemberBookingController;
use App\Http\Controllers\Api\V1\Member\MemberBookingPaymentController;
use App\Http\Controllers\Api\V1\Member\MemberDashboardController;
use App\Http\Controllers\Api\V1\Member\MemberMembershipController;
use App\Http\Controllers\Api\V1\Member\MemberNotificationController;
use App\Http\Controllers\Api\V1\Member\MemberPaymentController;
use App\Http\Controllers\Api\V1\Member\MemberPhysicalProgressController;
use App\Http\Controllers\Api\V1\Member\MemberProfileController;
use App\Http\Controllers\Api\V1\Member\MemberProgramController;
use App\Http\Controllers\Api\V1\Member\MemberRescheduleRequestController;
use App\Http\Controllers\Api\V1\Member\MemberTransactionController;
use App\Http\Controllers\Api\V1\Member\RatingController;
use App\Http\Controllers\Api\V1\Member\SelfTrainingController;
use App\Http\Controllers\Api\V1\Profile\ProfileAvatarController;
use App\Http\Controllers\Api\V1\Public\EquipmentController;
use App\Http\Controllers\Api\V1\Public\MembershipPlanController;
use App\Http\Controllers\Api\V1\Public\OperationHourController;
use App\Http\Controllers\Api\V1\Public\PakasirWebhookController;
use App\Http\Controllers\Api\V1\Public\PublicSettingsController;
use App\Http\Controllers\Api\V1\Public\TrainerAvailabilityController;
use App\Http\Controllers\Api\V1\Public\TrainerController;
use App\Http\Controllers\Api\V1\Trainer\TrainerClientController;
use App\Http\Controllers\Api\V1\Trainer\TrainerDashboardController;
use App\Http\Controllers\Api\V1\Trainer\TrainerDisplayPhotoController;
use App\Http\Controllers\Api\V1\Trainer\TrainerProfileController;
use App\Http\Controllers\Api\V1\Trainer\TrainerProgramController;
use App\Http\Controllers\Api\V1\Trainer\TrainerRescheduleRequestController;
use App\Http\Controllers\Api\V1\Trainer\TrainerScheduleController;
use App\Http\Controllers\Api\V1\Trainer\TrainerScheduleDateController;
use App\Http\Controllers\Api\V1\Trainer\TrainerSessionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::prefix('auth')->group(function () {
        Route::post('/login', [AuthController::class, 'login']);
        Route::post('/register', [AuthController::class, 'register']);

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/me', [AuthController::class, 'me']);
            Route::post('/logout', [AuthController::class, 'logout']);
            Route::post('/device-token', [DeviceTokenController::class, 'store']);
            Route::delete('/device-token', [DeviceTokenController::class, 'destroy']);
        });
    });

    // Foto profil (avatar) — REUSABLE untuk semua role (member & trainer),
    // berbasis user login. avatar_url disimpan sebagai relative path.
    Route::prefix('profile')->middleware('auth:sanctum')->group(function () {
        Route::post('/avatar', [ProfileAvatarController::class, 'store']);
        Route::delete('/avatar', [ProfileAvatarController::class, 'destroy']);
    });

    Route::prefix('public')->group(function () {
        Route::get('/membership-plans', [MembershipPlanController::class, 'index']);
        Route::get('/trainers', [TrainerController::class, 'index']);
        Route::get('/trainers/{trainerProfile}/ratings', [TrainerController::class, 'ratings']);
        Route::get('/trainers/{trainerProfile}/availability', [TrainerAvailabilityController::class, 'show']);
        Route::get('/equipment', [EquipmentController::class, 'index']);
        Route::get('/equipment/{equipment}', [EquipmentController::class, 'show']);
        Route::get('/operation-hours', [OperationHourController::class, 'index']);
        Route::get('/settings', [PublicSettingsController::class, 'show']);
        Route::post('/payments/pakasir/webhook', [PakasirWebhookController::class, 'handle']);

    });

    Route::prefix('member')
        ->middleware(['auth:sanctum', 'role:member'])
        ->group(function () {
            Route::get('/dashboard', [MemberDashboardController::class, 'index']);
            Route::get('/profile', [MemberProfileController::class, 'show']);
            Route::put('/profile', [MemberProfileController::class, 'update']);
            Route::get('/memberships', [MemberMembershipController::class, 'index']);
            Route::get('/transactions', [MemberTransactionController::class, 'index']);
            Route::post('/payments/checkout', [MemberPaymentController::class, 'checkout']);
            // Regenerate pembayaran untuk transaksi pending yang sudah expired
            // (tandai lama expired dulu -> buat baru, anti-duplikasi).
            Route::post('/payments/{referenceCode}/regenerate', [MemberPaymentController::class, 'regeneratePayment']);
            // Batalkan transaksi pending atas permintaan user (status -> cancelled).
            Route::post('/payments/{referenceCode}/cancel', [MemberPaymentController::class, 'cancelPayment']);
            // [SANDBOX/DEV ONLY] Simulasi pembayaran berhasil untuk testing.
            // Controller menolak (403) bila environment production.
            Route::post('/payments/{referenceCode}/simulate-success', [MemberPaymentController::class, 'simulateSuccess']);
            Route::get('/bookings', [MemberBookingController::class, 'index']);
            Route::post('/bookings', [MemberBookingController::class, 'store']);
            Route::post('/bookings/{booking}/reschedule', [MemberBookingController::class, 'reschedule']);
            Route::post('/bookings/{booking}/reservations/{reservation}/reschedule', [MemberBookingController::class, 'rescheduleReservation']);
            Route::post('/bookings/{booking}/reservations/{reservation}/reschedule-requests', [MemberRescheduleRequestController::class, 'store']);
            Route::get('/bookings/{booking}/reservations/{reservation}/reschedule-availability', [MemberRescheduleRequestController::class, 'availability']);
            Route::get('/reschedule-requests', [MemberRescheduleRequestController::class, 'index']);
            Route::post('/reschedule-requests/{rescheduleRequest}/accept', [MemberRescheduleRequestController::class, 'accept']);
            Route::post('/reschedule-requests/{rescheduleRequest}/reject', [MemberRescheduleRequestController::class, 'reject']);
            Route::post('/reschedule-requests/{rescheduleRequest}/cancel', [MemberRescheduleRequestController::class, 'cancel']);
            Route::get('/programs', [MemberProgramController::class, 'index']);
            Route::get('/programs/{id}', [MemberProgramController::class, 'show']);
            Route::get('/programs/{id}/tracker', [MemberProgramController::class, 'showTracker']);
            Route::post('/programs/{programId}/sessions/{sessionId}/ready', [MemberProgramController::class, 'markSessionReady']);
            Route::get('/physical-progress', [MemberPhysicalProgressController::class, 'index']);
            Route::post('/physical-progress', [MemberPhysicalProgressController::class, 'store']);
            Route::get('/notifications', [MemberNotificationController::class, 'index']);
            Route::post('/notifications/{id}/read', [MemberNotificationController::class, 'markAsRead']);
            Route::post('/notifications/read-all', [MemberNotificationController::class, 'markAllAsRead']);
            Route::post('/notifications/{id}/push', [MemberNotificationController::class, 'push']);

            // Self Training
            Route::get('/self-training', [SelfTrainingController::class, 'index']);
            Route::post('/self-training', [SelfTrainingController::class, 'store']);
            Route::get('/self-training/{id}', [SelfTrainingController::class, 'show']);
            Route::put('/self-training/{id}', [SelfTrainingController::class, 'update']);
            Route::delete('/self-training/{id}', [SelfTrainingController::class, 'destroy']);
            Route::post('/self-training/{programId}/sessions', [SelfTrainingController::class, 'storeSession']);
            Route::put('/self-training/{programId}/sessions/{sessionId}', [SelfTrainingController::class, 'updateSession']);
            Route::delete('/self-training/{programId}/sessions/{sessionId}', [SelfTrainingController::class, 'destroySession']);
            Route::post('/self-training/{programId}/sessions/{sessionId}/exercises', [SelfTrainingController::class, 'storeExercise']);
            Route::put('/self-training/{programId}/sessions/{sessionId}/exercises/{exerciseId}', [SelfTrainingController::class, 'updateExercise']);
            Route::post('/self-training/{programId}/sessions/{sessionId}/exercises/{exerciseId}/toggle', [SelfTrainingController::class, 'toggleExercise']);
            Route::delete('/self-training/{programId}/sessions/{sessionId}/exercises/{exerciseId}', [SelfTrainingController::class, 'destroyExercise']);

            // Booking Payment
            Route::get('/bookings/{booking}/payment-info', [MemberBookingPaymentController::class, 'getPaymentInfo']);
            Route::post('/bookings/{booking}/upload-proof', [MemberBookingPaymentController::class, 'uploadProof']);

            // Ratings
            Route::post('/ratings', [RatingController::class, 'store']);
            Route::get('/ratings', [RatingController::class, 'index']);
        });

    Route::prefix('trainer')
        ->middleware(['auth:sanctum', 'role:trainer'])
        ->group(function () {
            Route::get('/dashboard', [TrainerDashboardController::class, 'index']);
            Route::get('/profile', [TrainerProfileController::class, 'show']);
            Route::put('/profile', [TrainerProfileController::class, 'update']);
            Route::post('/profile/display-photo', [TrainerDisplayPhotoController::class, 'store']);
            Route::delete('/profile/display-photo', [TrainerDisplayPhotoController::class, 'destroy']);
            Route::get('/schedule', [TrainerScheduleController::class, 'show']);
            Route::put('/schedule', [TrainerScheduleController::class, 'update']);
            Route::get('/schedule-dates', [TrainerScheduleDateController::class, 'index']);
            Route::put('/schedule-dates/{date}', [TrainerScheduleDateController::class, 'update']);
            Route::post('/schedule-dates/{date}/reset', [TrainerScheduleDateController::class, 'reset']);
            Route::get('/clients', [TrainerClientController::class, 'index']);
            Route::get('/clients/{memberProfile}', [TrainerClientController::class, 'show']);
            Route::get('/sessions', [TrainerSessionController::class, 'index']);
            Route::get('/sessions/{booking}', [TrainerSessionController::class, 'show']);
            Route::post('/sessions/{booking}/confirm', [TrainerSessionController::class, 'confirm']);
            Route::post('/sessions/{booking}/reject', [TrainerSessionController::class, 'reject']);
            Route::post('/sessions/{booking}/reschedule', [TrainerSessionController::class, 'reschedule']);
            Route::post('/sessions/{booking}/reservations/{reservation}/reschedule', [TrainerSessionController::class, 'rescheduleReservation']);
            Route::post('/sessions/{booking}/reservations/{reservation}/reschedule-requests', [TrainerRescheduleRequestController::class, 'store']);
            Route::get('/sessions/{booking}/reservations/{reservation}/reschedule-availability', [TrainerRescheduleRequestController::class, 'availability']);
            Route::get('/reschedule-requests', [TrainerRescheduleRequestController::class, 'index']);
            Route::post('/reschedule-requests/{rescheduleRequest}/accept', [TrainerRescheduleRequestController::class, 'accept']);
            Route::post('/reschedule-requests/{rescheduleRequest}/reject', [TrainerRescheduleRequestController::class, 'reject']);
            Route::post('/reschedule-requests/{rescheduleRequest}/cancel', [TrainerRescheduleRequestController::class, 'cancel']);
            Route::post('/sessions/{booking}/verify-payment', [TrainerSessionController::class, 'verifyPayment']);
            Route::get('/notifications', [MemberNotificationController::class, 'index']);
            Route::post('/notifications/{id}/read', [MemberNotificationController::class, 'markAsRead']);
            Route::post('/notifications/read-all', [MemberNotificationController::class, 'markAllAsRead']);
            Route::get('/programs', [TrainerProgramController::class, 'index']);
            Route::post('/programs', [TrainerProgramController::class, 'store']);
            Route::get('/programs/{trainingProgram}', [TrainerProgramController::class, 'show']);
            Route::post('/programs/{trainingProgram}/close-early', [TrainerProgramController::class, 'closeEarly']);
            Route::post('/programs/{trainingProgram}/sessions', [TrainerProgramController::class, 'storeSession']);
            Route::get('/program-sessions/{id}/progress', [TrainerProgramController::class, 'showSessionProgress']);
            Route::post('/program-sessions/{id}/progress', [TrainerProgramController::class, 'updateSessionProgress']);
            Route::post('/program-sessions/{id}/complete', [TrainerProgramController::class, 'completeSessionProgress']);
            Route::put('/program-sessions/{id}', [TrainerProgramController::class, 'updateSession']);
            Route::post('/program-sessions/{id}/exercises', [TrainerProgramController::class, 'storeSessionExercise']);
            Route::put('/program-session-exercises/{id}', [TrainerProgramController::class, 'updateSessionExercise']);
            Route::delete('/program-session-exercises/{id}', [TrainerProgramController::class, 'destroySessionExercise']);
        });

});
