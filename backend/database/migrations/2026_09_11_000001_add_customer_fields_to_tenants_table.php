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
        Schema::table('tenants', function (Blueprint $table) {
            $table->string('customer_type', 20)->default('individual')->after('name'); // 'individual' or 'company'
            $table->string('tax_number', 50)->nullable()->after('customer_type'); // NPWP
            $table->string('city', 100)->nullable()->after('store_address');
            $table->string('postal_code', 20)->nullable()->after('city');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn(['customer_type', 'tax_number', 'city', 'postal_code']);
        });
    }
};
