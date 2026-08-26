<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('self_training_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('self_training_program_id')->constrained('self_training_programs')->cascadeOnDelete();
            $table->unsignedInteger('sequence_order');
            $table->string('title');
            $table->string('focus')->nullable();
            $table->unsignedInteger('duration_minutes')->nullable();
            $table->string('status', 30)->default('active');
            $table->timestamps();

            $table->unique(['self_training_program_id', 'sequence_order'], 'sts_program_seq_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('self_training_sessions');
    }
};
