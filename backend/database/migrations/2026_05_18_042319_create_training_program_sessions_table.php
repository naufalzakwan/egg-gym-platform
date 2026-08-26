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
        Schema::create('training_program_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('training_program_id')->constrained('training_programs')->cascadeOnDelete();
            $table->unsignedInteger('sequence_order');
            $table->string('title');
            $table->string('focus')->nullable();
            $table->unsignedInteger('duration_minutes')->nullable();
            $table->string('status', 30)->default('locked');
            $table->string('unlock_rule', 50)->nullable()->default('after_previous_complete');
            $table->text('coach_note')->nullable();
            $table->timestamps();
            $table->unique(
                ['training_program_id', 'sequence_order'],
                'tps_program_sequence_unique'
            );
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('training_program_sessions');
    }
};
