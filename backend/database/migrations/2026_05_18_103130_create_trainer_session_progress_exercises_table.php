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
        Schema::create('trainer_session_progress_exercises', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('trainer_session_progress_id');
            $table->unsignedBigInteger('training_program_session_exercise_id');
            $table->unsignedInteger('completed_sets')->default(0);
            $table->unsignedInteger('total_sets');
            $table->string('status', 30)->default('locked');
            $table->timestamp('last_marked_at')->nullable();
            $table->timestamps();

            $table->unique(
                ['trainer_session_progress_id', 'training_program_session_exercise_id'],
                'tspe_progress_exercise_unique'
            );

            $table->foreign('trainer_session_progress_id', 'tspe_progress_fk')
                ->references('id')
                ->on('trainer_session_progresses')
                ->cascadeOnDelete();

            $table->foreign('training_program_session_exercise_id', 'tspe_session_ex_fk')
                ->references('id')
                ->on('training_program_session_exercises')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trainer_session_progress_exercises');
    }
};
