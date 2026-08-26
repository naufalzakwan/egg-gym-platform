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
        Schema::create('trainer_session_progresses', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('training_program_id');
            $table->unsignedBigInteger('training_program_session_id');
            $table->unsignedBigInteger('trainer_profile_id');
            $table->unsignedBigInteger('member_profile_id');
            $table->decimal('progress_percent', 5, 2)->default(0);
            $table->unsignedInteger('current_exercise_order')->nullable();
            $table->string('status', 30)->default('active');
            $table->timestamp('synced_at')->nullable();
            $table->text('trainer_note')->nullable();
            $table->timestamps();

            $table->unique('training_program_session_id', 'tsp_session_unique');

            $table->foreign('training_program_id', 'tsp_program_fk')
                ->references('id')
                ->on('training_programs')
                ->cascadeOnDelete();

            $table->foreign('training_program_session_id', 'tsp_session_fk')
                ->references('id')
                ->on('training_program_sessions')
                ->cascadeOnDelete();

            $table->foreign('trainer_profile_id', 'tsp_trainer_fk')
                ->references('id')
                ->on('trainer_profiles')
                ->cascadeOnDelete();

            $table->foreign('member_profile_id', 'tsp_member_fk')
                ->references('id')
                ->on('member_profiles')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trainer_session_progresses');
    }
};
