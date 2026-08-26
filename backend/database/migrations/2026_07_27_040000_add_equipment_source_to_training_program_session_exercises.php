<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('training_program_session_exercises', function (Blueprint $table) {
            $table->unsignedBigInteger('equipment_id')->nullable()->after('exercise_library_id');
            $table->unsignedBigInteger('gym_equipment_movement_id')->nullable()->after('equipment_id');
            $table->string('equipment_name')->nullable()->after('gym_equipment_movement_id');
            $table->foreign('equipment_id', 'tpse_equipment_fk')
                ->references('id')->on('equipments')->nullOnDelete();
            $table->foreign('gym_equipment_movement_id', 'tpse_movement_fk')
                ->references('id')->on('gym_equipment_movements')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('training_program_session_exercises', function (Blueprint $table) {
            $table->dropForeign('tpse_movement_fk');
            $table->dropForeign('tpse_equipment_fk');
            $table->dropColumn(['gym_equipment_movement_id', 'equipment_id', 'equipment_name']);
        });
    }
};
