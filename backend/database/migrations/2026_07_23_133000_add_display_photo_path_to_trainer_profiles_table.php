<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('trainer_profiles', 'display_photo_path')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                $table->string('display_photo_path')->nullable()->after('availability_note');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('trainer_profiles', 'display_photo_path')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                $table->dropColumn('display_photo_path');
            });
        }
    }
};
