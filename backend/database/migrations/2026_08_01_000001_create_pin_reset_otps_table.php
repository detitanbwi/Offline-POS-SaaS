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
        Schema::create('pin_reset_otps', function (Blueprint $table) {
            $table->id();
            $table->string('email')->index();
            $table->string('otp_code', 6);
            $table->string('reset_token')->nullable()->unique(); // Token setelah OTP berhasil diverifikasi
            $table->unsignedTinyInteger('attempts')->default(0); // Jumlah percobaan salah (max 3x)
            $table->boolean('is_verified')->default(false);
            $table->timestamp('expires_at'); // Berlaku 5 menit
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('pin_reset_otps');
    }
};
