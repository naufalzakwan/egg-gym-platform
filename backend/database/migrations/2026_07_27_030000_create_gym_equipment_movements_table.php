<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gym_equipment_movements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('gym_equipment_id')->constrained('equipments')->cascadeOnDelete();
            $table->string('movement_name');
            $table->string('target_area');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['gym_equipment_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('gym_equipment_movements');
    }
};
