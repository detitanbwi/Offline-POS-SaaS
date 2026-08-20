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
        Schema::create('license_check_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id');
            $table->uuid('license_token_id')->nullable();
            $table->string('status'); // 'success', 'failed', 'offline'
            $table->string('trigger_type'); // 'automatic', 'manual'
            $table->integer('remaining_time_seconds')->default(0);
            $table->timestamps();

            $table->foreign('tenant_id')
                ->references('id')
                ->on('tenants')
                ->onDelete('cascade');
                
            $table->foreign('license_token_id')
                ->references('id')
                ->on('license_tokens')
                ->onDelete('set null');
                
            $table->index('tenant_id');
            $table->index('license_token_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('license_check_logs');
    }
};
