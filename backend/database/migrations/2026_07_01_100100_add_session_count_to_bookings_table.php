<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Idempotent: kolom bisa sudah ada dari lingkungan sebelumnya.
        if (! Schema::hasColumn('bookings', 'session_count')) {
            Schema::table('bookings', function (Blueprint $table) {
                // Jumlah sesi yang diambil member (dipilih via tombol +/- saat bayar).
                $table->unsignedInteger('session_count')->default(1)->after('location');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('bookings', 'session_count')) {
            Schema::table('bookings', function (Blueprint $table) {
                $table->dropColumn('session_count');
            });
        }
    }
};
