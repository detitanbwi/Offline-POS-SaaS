<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('packages', function (Blueprint $table) {
            if (! Schema::hasColumn('packages', 'validity_type')) {
                $table->string('validity_type')->default('duration')->after('price');
            }
            if (! Schema::hasColumn('packages', 'start_date')) {
                $table->date('start_date')->nullable()->after('default_duration_days');
            }
            if (! Schema::hasColumn('packages', 'end_date')) {
                $table->date('end_date')->nullable()->after('start_date');
            }
            if (Schema::hasColumn('packages', 'sort_order')) {
                $table->dropColumn('sort_order');
            }
        });

        // Ensure invoice_item_id in subscriptions is nullable
        Schema::table('subscriptions', function (Blueprint $table) {
            $table->uuid('invoice_item_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('packages', function (Blueprint $table) {
            if (! Schema::hasColumn('packages', 'sort_order')) {
                $table->integer('sort_order')->default(0);
            }
            if (Schema::hasColumn('packages', 'validity_type')) {
                $table->dropColumn('validity_type');
            }
            if (Schema::hasColumn('packages', 'start_date')) {
                $table->dropColumn('start_date');
            }
            if (Schema::hasColumn('packages', 'end_date')) {
                $table->dropColumn('end_date');
            }
        });
    }
};
