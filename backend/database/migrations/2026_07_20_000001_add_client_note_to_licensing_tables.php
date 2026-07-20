<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoice_items', function (Blueprint $table) {
            $table->string('client_note')->nullable()->after('package_name');
        });

        Schema::table('subscriptions', function (Blueprint $table) {
            $table->string('client_note')->nullable()->after('package_name');
        });

        Schema::table('license_tokens', function (Blueprint $table) {
            $table->string('client_note')->nullable()->after('token_key');
            $table->string('token_key', 50)->change();
        });
    }

    public function down(): void
    {
        Schema::table('license_tokens', function (Blueprint $table) {
            $table->dropColumn('client_note');
            $table->string('token_key', 30)->change();
        });

        Schema::table('subscriptions', function (Blueprint $table) {
            $table->dropColumn('client_note');
        });

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->dropColumn('client_note');
        });
    }
};
