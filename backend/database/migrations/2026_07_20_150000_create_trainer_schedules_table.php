<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trainer_schedules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trainer_profile_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('day_of_week');
            $table->time('start_time');
            $table->time('end_time');
            $table->timestamps();

            $table->unique(
                ['trainer_profile_id', 'day_of_week', 'start_time', 'end_time'],
                'trainer_schedules_unique_shift'
            );
            $table->index(
                ['trainer_profile_id', 'day_of_week'],
                'trainer_schedules_trainer_day_idx'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trainer_schedules');
    }
};
