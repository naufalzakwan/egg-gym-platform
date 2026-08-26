<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trainer_profiles', function (Blueprint $table) {
            // Tier coach (elite/pro/standard) untuk badge di card.
            if (! Schema::hasColumn('trainer_profiles', 'tier')) {
                $table->string('tier', 20)->default('pro')->after('specialty');
            }
            // Kapasitas maksimum klien aktif (untuk tampilan "24 / 30 Max").
            if (! Schema::hasColumn('trainer_profiles', 'max_clients')) {
                $table->unsignedInteger('max_clients')->default(30)->after('tier');
            }
        });
    }

    public function down(): void
    {
        Schema::table('trainer_profiles', function (Blueprint $table) {
            if (Schema::hasColumn('trainer_profiles', 'tier')) {
                $table->dropColumn('tier');
            }
            if (Schema::hasColumn('trainer_profiles', 'max_clients')) {
                $table->dropColumn('max_clients');
            }
        });
    }
};
