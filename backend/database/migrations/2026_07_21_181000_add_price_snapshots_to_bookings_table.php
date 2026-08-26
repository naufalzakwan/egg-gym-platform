<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->decimal('price_per_session_snapshot', 15, 2)
                ->nullable()
                ->after('session_count');
            $table->decimal('total_amount_snapshot', 15, 2)
                ->nullable()
                ->after('price_per_session_snapshot');
        });
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropColumn([
                'price_per_session_snapshot',
                'total_amount_snapshot',
            ]);
        });
    }
};
