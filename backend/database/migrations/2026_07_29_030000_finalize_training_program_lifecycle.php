<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('training_programs')
            ->where('status', 'active')
            ->whereExists(function ($query) {
                $query->selectRaw('1')
                    ->from('training_program_sessions')
                    ->whereColumn('training_program_sessions.training_program_id', 'training_programs.id');
            })
            ->whereNotExists(function ($query) {
                $query->selectRaw('1')
                    ->from('training_program_sessions')
                    ->whereColumn('training_program_sessions.training_program_id', 'training_programs.id')
                    ->where('training_program_sessions.status', '!=', 'completed');
            })
            ->update([
                'status' => 'completed',
                'ended_at' => DB::raw('COALESCE(ended_at, CURRENT_DATE)'),
                'updated_at' => now(),
            ]);

        Schema::table('training_programs', function (Blueprint $table) {
            $table->unique('booking_id', 'training_programs_booking_unique');
        });
    }

    public function down(): void
    {
        Schema::table('training_programs', function (Blueprint $table) {
            $table->dropUnique('training_programs_booking_unique');
        });
    }
};
