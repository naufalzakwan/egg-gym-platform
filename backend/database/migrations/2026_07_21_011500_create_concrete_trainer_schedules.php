<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trainer_profiles', function (Blueprint $table) {
            $table->unsignedBigInteger('schedule_template_version')->default(1);
        });

        Schema::table('trainer_schedules', function (Blueprint $table) {
            $table->uuid('template_key')->nullable()->after('trainer_profile_id');
            $table->unique('template_key', 'trainer_schedules_template_key_unique');
        });

        DB::table('trainer_schedules')
            ->whereNull('template_key')
            ->orderBy('id')
            ->eachById(function (object $schedule): void {
                DB::table('trainer_schedules')
                    ->where('id', $schedule->id)
                    ->update(['template_key' => (string) Str::uuid()]);
            });

        DB::statement('ALTER TABLE trainer_schedules MODIFY template_key CHAR(36) NOT NULL');

        Schema::create('trainer_schedule_dates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trainer_profile_id')->constrained()->cascadeOnDelete();
            $table->date('schedule_date');
            $table->string('state', 16); // open | closed
            $table->string('source', 16); // generated | manual
            $table->unsignedBigInteger('template_version')->nullable();
            $table->string('template_fingerprint', 64)->nullable();
            $table->string('operation_fingerprint', 64)->nullable();
            $table->timestamp('generated_at')->nullable();
            $table->timestamp('overridden_at')->nullable();
            $table->foreignId('overridden_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('override_reason')->nullable();
            $table->unsignedInteger('lock_version')->default(1);
            $table->timestamps();

            $table->unique(
                ['trainer_profile_id', 'schedule_date'],
                'trainer_schedule_dates_trainer_date_unique'
            );
            $table->index(
                ['schedule_date', 'state', 'trainer_profile_id'],
                'trainer_schedule_dates_lookup_idx'
            );
            $table->index(['source', 'schedule_date'], 'trainer_schedule_dates_source_idx');
        });

        Schema::create('trainer_schedule_date_shifts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trainer_schedule_date_id')
                ->constrained('trainer_schedule_dates')
                ->cascadeOnDelete();
            $table->foreignId('source_trainer_schedule_id')
                ->nullable()
                ->constrained('trainer_schedules')
                ->nullOnDelete();
            $table->uuid('source_template_key')->nullable();
            $table->time('start_time');
            $table->time('end_time');
            $table->timestamps();

            $table->unique(
                ['trainer_schedule_date_id', 'start_time', 'end_time'],
                'trainer_date_shifts_unique_interval'
            );
            $table->index('source_trainer_schedule_id', 'trainer_date_shifts_source_idx');
        });

        Schema::table('bookings', function (Blueprint $table) {
            $table->foreignId('trainer_schedule_date_id')
                ->nullable()
                ->after('trainer_profile_id')
                ->constrained('trainer_schedule_dates')
                ->restrictOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('trainer_schedule_date_id');
        });
        Schema::dropIfExists('trainer_schedule_date_shifts');
        Schema::dropIfExists('trainer_schedule_dates');

        Schema::table('trainer_schedules', function (Blueprint $table) {
            $table->dropUnique('trainer_schedules_template_key_unique');
            $table->dropColumn('template_key');
        });
        Schema::table('trainer_profiles', function (Blueprint $table) {
            $table->dropColumn('schedule_template_version');
        });
    }
};
