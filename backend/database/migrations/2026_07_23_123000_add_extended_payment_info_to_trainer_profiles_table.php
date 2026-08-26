<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trainer_profiles', function (Blueprint $table) {
            if (! Schema::hasColumn('trainer_profiles', 'dana_account_name')) {
                $table->string('dana_account_name', 100)->nullable()->after('dana_number');
            }
            if (! Schema::hasColumn('trainer_profiles', 'other_payment_method')) {
                $table->string('other_payment_method', 50)->nullable()->after('dana_account_name');
            }
            if (! Schema::hasColumn('trainer_profiles', 'other_payment_number')) {
                $table->string('other_payment_number', 100)->nullable()->after('other_payment_method');
            }
            if (! Schema::hasColumn('trainer_profiles', 'other_payment_account_name')) {
                $table->string('other_payment_account_name', 100)->nullable()->after('other_payment_number');
            }
        });
    }

    public function down(): void
    {
        $columns = collect([
            'dana_account_name',
            'other_payment_method',
            'other_payment_number',
            'other_payment_account_name',
        ])->filter(fn (string $column) => Schema::hasColumn('trainer_profiles', $column))->all();

        if ($columns !== []) {
            Schema::table('trainer_profiles', function (Blueprint $table) use ($columns) {
                $table->dropColumn($columns);
            });
        }
    }
};
