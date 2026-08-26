<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'UPDATE trainer_schedules '
            .'SET session_duration_minutes = TIMESTAMPDIFF(MINUTE, start_time, end_time)'
        );
        DB::statement(
            'UPDATE trainer_schedule_date_shifts '
            .'SET session_duration_minutes = TIMESTAMPDIFF(MINUTE, start_time, end_time)'
        );
    }

    public function down(): void
    {
        // Normalized values cannot be reconstructed safely.
    }
};
