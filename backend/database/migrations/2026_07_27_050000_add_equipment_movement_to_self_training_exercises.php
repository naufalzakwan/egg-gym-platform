<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('self_training_exercises', function (Blueprint $table) {
            $table->unsignedBigInteger('gym_equipment_movement_id')->nullable()->after('equipment_id');
            $table->string('equipment_name')->nullable()->after('gym_equipment_movement_id');
            $table->foreign('gym_equipment_movement_id', 'ste_movement_fk')
                ->references('id')->on('gym_equipment_movements')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('self_training_exercises', function (Blueprint $table) {
            $table->dropForeign('ste_movement_fk');
            $table->dropColumn(['gym_equipment_movement_id', 'equipment_name']);
        });
    }
};
