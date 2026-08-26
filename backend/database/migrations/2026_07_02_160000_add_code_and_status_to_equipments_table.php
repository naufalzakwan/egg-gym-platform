<?php

use App\Models\Equipment;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('equipments', function (Blueprint $table) {
            // Kode alat unik (format EQ-001) untuk badge ID di card.
            if (! Schema::hasColumn('equipments', 'code')) {
                $table->string('code', 20)->nullable()->unique()->after('id');
            }
            // Status operasional 3-state: available / maintenance / broken.
            if (! Schema::hasColumn('equipments', 'status')) {
                $table->string('status', 20)->default('available')->after('is_active');
            }
        });

        // Backfill code untuk data lama yang belum punya (EQ-001, EQ-002, ...).
        if (Schema::hasColumn('equipments', 'code')) {
            $counter = 1;
            Equipment::query()->whereNull('code')->orderBy('id')->get()->each(function ($eq) use (&$counter) {
                $eq->code = 'EQ-'.str_pad((string) $counter, 3, '0', STR_PAD_LEFT);
                // Turunkan status awal dari is_active bila ada.
                if (empty($eq->status)) {
                    $eq->status = ($eq->is_active ?? true) ? 'available' : 'maintenance';
                }
                $eq->save();
                $counter++;
            });
        }
    }

    public function down(): void
    {
        Schema::table('equipments', function (Blueprint $table) {
            if (Schema::hasColumn('equipments', 'code')) {
                $table->dropUnique('equipments_code_unique');
                $table->dropColumn('code');
            }
            if (Schema::hasColumn('equipments', 'status')) {
                $table->dropColumn('status');
            }
        });
    }
};
