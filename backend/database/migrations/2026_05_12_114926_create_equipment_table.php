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
        Schema::create('equipments', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('category', 50);
            $table->text('description');
            $table->string('focus');
            $table->string('stage_label')->nullable();
            $table->string('usage_window')->nullable();
            $table->string('best_for')->nullable();
            $table->string('difficulty')->nullable();
            $table->json('key_benefits_json')->nullable();
            $table->json('usage_flow_json')->nullable();
            $table->json('safety_notes_json')->nullable();
            $table->json('suggested_moves_json')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('equipments');
    }
};
