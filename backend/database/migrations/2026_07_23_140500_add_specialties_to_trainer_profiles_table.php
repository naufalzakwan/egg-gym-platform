<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('trainer_profiles', 'specialties')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                $table->json('specialties')->nullable()->after('specialty');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('trainer_profiles', 'specialties')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                $table->dropColumn('specialties');
            });
        }
    }
};
