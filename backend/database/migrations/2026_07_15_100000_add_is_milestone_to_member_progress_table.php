<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('member_progress', function (Blueprint $table) {
            // Penanda checkpoint milestone (dari toggle di form Flutter).
            $table->boolean('is_milestone')->default(false)->after('note');
        });
    }

    public function down(): void
    {
        Schema::table('member_progress', function (Blueprint $table) {
            $table->dropColumn('is_milestone');
        });
    }
};
