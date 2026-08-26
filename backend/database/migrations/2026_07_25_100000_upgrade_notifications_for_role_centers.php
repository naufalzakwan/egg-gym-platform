<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('notifications', function (Blueprint $table) {
            $table->json('data_json')->nullable()->after('channel');
            $table->string('event_key', 191)->nullable()->after('data_json');
            $table->string('priority', 20)->default('normal')->after('event_key');
            $table->timestamp('read_at')->nullable()->after('is_read');
            $table->unique(['user_id', 'event_key'], 'notifications_user_event_unique');
            $table->index(['user_id', 'is_read', 'sent_at'], 'notifications_user_unread_sent');
        });
    }

    public function down(): void
    {
        Schema::table('notifications', function (Blueprint $table) {
            $table->dropUnique('notifications_user_event_unique');
            $table->dropIndex('notifications_user_unread_sent');
            $table->dropColumn(['data_json', 'event_key', 'priority', 'read_at']);
        });
    }
};
