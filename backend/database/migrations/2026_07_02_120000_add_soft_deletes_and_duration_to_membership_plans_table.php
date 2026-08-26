<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('membership_plans', function (Blueprint $table) {
            // Soft delete: paket dinonaktifkan tanpa menghapus data, agar member
            // yang sudah memakai paket tidak terdampak (sesuai spec MD).
            if (! Schema::hasColumn('membership_plans', 'deleted_at')) {
                $table->softDeletes();
            }
            // Durasi paket dalam hari (spec MD: field "DURASI (HARI)").
            if (! Schema::hasColumn('membership_plans', 'duration_days')) {
                $table->unsignedInteger('duration_days')->default(30)->after('billing_period');
            }
        });
    }

    public function down(): void
    {
        Schema::table('membership_plans', function (Blueprint $table) {
            if (Schema::hasColumn('membership_plans', 'deleted_at')) {
                $table->dropSoftDeletes();
            }
            if (Schema::hasColumn('membership_plans', 'duration_days')) {
                $table->dropColumn('duration_days');
            }
        });
    }
};
