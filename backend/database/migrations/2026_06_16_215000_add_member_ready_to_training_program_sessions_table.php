<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('training_program_sessions', function (Blueprint $table) {
            $table->boolean('member_ready')->default(false)->after('coach_note');
            $table->timestamp('member_ready_at')->nullable()->after('member_ready');
        });
    }

    public function down(): void
    {
        Schema::table('training_program_sessions', function (Blueprint $table) {
            $table->dropColumn(['member_ready', 'member_ready_at']);
        });
    }
};
