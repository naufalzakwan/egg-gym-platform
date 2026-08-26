<?php

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_admin_owner')->default(false)->after('status')->index();
        });

        $adminRoleId = Role::query()->where('name', 'admin')->value('id');
        if ($adminRoleId && ! User::query()->where('role_id', $adminRoleId)->where('is_admin_owner', true)->exists()) {
            User::query()
                ->where('role_id', $adminRoleId)
                ->where('status', 'active')
                ->oldest('id')
                ->limit(1)
                ->update(['is_admin_owner' => true]);
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['is_admin_owner']);
            $table->dropColumn('is_admin_owner');
        });
    }
};
