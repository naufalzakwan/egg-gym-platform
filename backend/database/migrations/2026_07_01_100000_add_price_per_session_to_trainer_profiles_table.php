<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Idempotent: kolom bisa sudah ada dari lingkungan sebelumnya.
        if (! Schema::hasColumn('trainer_profiles', 'price_per_session')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                // Harga per sesi PT, custom per masing-masing akun trainer.
                $table->decimal('price_per_session', 12, 2)->nullable()->after('dana_number');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('trainer_profiles', 'price_per_session')) {
            Schema::table('trainer_profiles', function (Blueprint $table) {
                $table->dropColumn('price_per_session');
            });
        }
    }
};
