<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('member_progress_photos', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('member_progress_id');
            $table->string('photo_type', 30);
            $table->string('photo_url', 255);
            $table->timestamps();

            $table->unique(
                ['member_progress_id', 'photo_type'],
                'mpp_progress_type_unique'
            );

            $table->foreign('member_progress_id', 'mpp_progress_fk')
                ->references('id')
                ->on('member_progress')
                ->cascadeOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('member_progress_photos');
    }
};
