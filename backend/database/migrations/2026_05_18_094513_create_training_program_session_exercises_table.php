<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('training_program_session_exercises', function (Blueprint $table) {
            $table->id();

            $table->unsignedBigInteger('training_program_session_id');

            // master exercise belum dibuat, jadi untuk sekarang dibiarkan nullable tanpa FK
            $table->unsignedBigInteger('exercise_library_id')->nullable();

            $table->unsignedInteger('sequence_order');
            $table->string('custom_name')->nullable();
            $table->string('custom_target_muscle')->nullable();
            $table->unsignedInteger('sets');
            $table->unsignedInteger('reps');
            $table->unsignedInteger('rest_seconds')->nullable();
            $table->text('cue_text')->nullable();
            $table->string('status', 30)->default('locked');
            $table->timestamps();

            $table->unique(
                ['training_program_session_id', 'sequence_order'],
                'tpse_session_sequence_unique'
            );

            $table->foreign('training_program_session_id', 'tpse_session_fk')
                ->references('id')
                ->on('training_program_sessions')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('training_program_session_exercises');
    }
};
