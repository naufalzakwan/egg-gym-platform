<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Idempotent: kolom bisa sudah ada dari lingkungan sebelumnya.
        if (! Schema::hasColumn('equipments', 'image_path')) {
            Schema::table('equipments', function (Blueprint $table) {
                // Path relatif foto alat di disk 'public' (storage/app/public).
                // Ditampilkan di admin + nantinya di guest/member/trainer.
                $table->string('image_path')->nullable()->after('description');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('equipments', 'image_path')) {
            Schema::table('equipments', function (Blueprint $table) {
                $table->dropColumn('image_path');
            });
        }
    }
};
