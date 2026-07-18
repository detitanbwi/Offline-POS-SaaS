<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('license_token_id');
            $table->uuid('tenant_id');
            $table->string('fingerprint_hash', 64);
            $table->string('android_id_hash', 64)->nullable();
            $table->string('manufacturer')->nullable();
            $table->string('brand')->nullable();
            $table->string('model')->nullable();
            $table->string('installation_uuid_hash', 64)->nullable();
            $table->string('status')->default('active');
            $table->timestamp('activated_at');
            $table->timestamp('last_validated_at')->nullable();
            $table->timestamps();

            $table->foreign('license_token_id')
                ->references('id')
                ->on('license_tokens')
                ->onDelete('cascade');

            $table->foreign('tenant_id')
                ->references('id')
                ->on('tenants')
                ->onDelete('cascade');

            $table->unique(['license_token_id', 'fingerprint_hash']);
            $table->index('tenant_id');
            $table->index('status');
            $table->index('fingerprint_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};
