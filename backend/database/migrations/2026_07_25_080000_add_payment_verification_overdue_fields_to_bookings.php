<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->timestamp('payment_proof_uploaded_at')->nullable()->after('payment_proof_path');
            $table->timestamp('verification_overdue_notified_at')->nullable()->after('payment_verified_at');
            $table->index(
                ['status', 'expired_at', 'verification_overdue_notified_at'],
                'bookings_verification_overdue_lookup'
            );
        });
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropIndex('bookings_verification_overdue_lookup');
            $table->dropColumn(['payment_proof_uploaded_at', 'verification_overdue_notified_at']);
        });
    }
};
