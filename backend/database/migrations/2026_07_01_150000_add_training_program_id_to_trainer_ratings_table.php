<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Idempotent: kolom bisa sudah ada dari lingkungan sebelumnya.
        if (! Schema::hasColumn('trainer_ratings', 'training_program_id')) {
            Schema::table('trainer_ratings', function (Blueprint $table) {
                // Rating dikunci pada program (selalu ada), bukan booking_id
                // yang bisa NULL karena program dibuat lewat Program Builder.
                $table->foreignId('training_program_id')
                    ->nullable()
                    ->after('booking_id')
                    ->constrained('training_programs')
                    ->nullOnDelete();

                // Satu member hanya boleh memberi satu rating per program selesai.
                $table->unique(
                    ['member_profile_id', 'training_program_id'],
                    'tr_member_program_unique'
                );
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('trainer_ratings', 'training_program_id')) {
            Schema::table('trainer_ratings', function (Blueprint $table) {
                $table->dropUnique('tr_member_program_unique');
                $table->dropConstrainedForeignId('training_program_id');
            });
        }
    }
};
