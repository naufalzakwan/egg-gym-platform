<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('training_program_sessions', function (Blueprint $table) {
            $table->foreignId('booking_session_reservation_id')
                ->nullable()
                ->after('training_program_id')
                ->unique()
                ->constrained('booking_session_reservations')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('training_program_sessions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('booking_session_reservation_id');
        });
    }
};
