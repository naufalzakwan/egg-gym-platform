<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('self_training_exercises', function (Blueprint $table) {
            $table->id();
            $table->foreignId('self_training_session_id')->constrained('self_training_sessions')->cascadeOnDelete();
            $table->unsignedBigInteger('equipment_id')->nullable();
            $table->unsignedInteger('sequence_order');
            $table->string('name');
            $table->string('target_muscle')->nullable();
            $table->unsignedInteger('sets');
            $table->unsignedInteger('reps');
            $table->unsignedInteger('rest_seconds')->nullable();
            $table->string('load')->nullable();
            $table->text('notes')->nullable();
            $table->boolean('is_completed')->default(false);
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->foreign('equipment_id')
                ->references('id')
                ->on('equipments')
                ->nullOnDelete();

            $table->unique(['self_training_session_id', 'sequence_order'], 'ste_session_seq_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('self_training_exercises');
    }
};
