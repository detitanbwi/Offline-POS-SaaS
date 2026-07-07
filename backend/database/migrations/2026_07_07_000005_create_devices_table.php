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
            $table->foreignId('license_id')->constrained('licenses')->onDelete('cascade');
            $table->string('fingerprint_hash');         // SHA256 hash only
            $table->string('device_name')->nullable();
            $table->string('device_model')->nullable();
            $table->string('device_brand')->nullable();
            $table->enum('status', ['active', 'deactivated'])->default('active');
            $table->timestamp('activated_at');
            $table->timestamp('last_validated_at')->nullable();
            $table->timestamps();
            $table->unique(['license_id', 'fingerprint_hash']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};
