<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trainer_schedules', function (Blueprint $table) {
            $table->unsignedSmallInteger('session_duration_minutes')->default(90)->after('end_time');
        });

        Schema::table('trainer_schedule_date_shifts', function (Blueprint $table) {
            $table->unsignedSmallInteger('session_duration_minutes')->default(90)->after('end_time');
        });

        Schema::table('bookings', function (Blueprint $table) {
            $table->unsignedSmallInteger('session_duration_minutes')->nullable()->after('end_time');
        });

        DB::statement(
            'UPDATE bookings SET session_duration_minutes = TIMESTAMPDIFF(MINUTE, start_time, end_time) '
            .'WHERE session_duration_minutes IS NULL'
        );

        if (! DB::table('bookings')->whereNull('session_duration_minutes')->exists()) {
            DB::statement(
                'ALTER TABLE bookings MODIFY session_duration_minutes SMALLINT UNSIGNED NOT NULL'
            );
        }
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropColumn('session_duration_minutes');
        });
        Schema::table('trainer_schedule_date_shifts', function (Blueprint $table) {
            $table->dropColumn('session_duration_minutes');
        });
        Schema::table('trainer_schedules', function (Blueprint $table) {
            $table->dropColumn('session_duration_minutes');
        });
    }
};
