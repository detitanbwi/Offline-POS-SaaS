<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('licenses', function (Blueprint $table) {
            $table->uuid('tenant_id')->nullable()->after('id');
            $table->uuid('subscription_id')->nullable()->after('tenant_id');
            $table->integer('device_limit')->default(1)->after('device_id');
            $table->integer('device_count')->default(0)->after('device_limit');
            $table->string('server_secret')->nullable()->after('device_count');
            $table->timestamp('activated_at')->nullable()->after('status');
            $table->timestamp('last_validated_at')->nullable()->after('activated_at');

            $table->foreign('tenant_id')->references('id')->on('tenants')->onDelete('cascade');
            $table->foreign('subscription_id')->references('id')->on('subscriptions')->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::table('licenses', function (Blueprint $table) {
            $table->dropForeign(['tenant_id']);
            $table->dropForeign(['subscription_id']);
            $table->dropColumn([
                'tenant_id',
                'subscription_id',
                'device_limit',
                'device_count',
                'server_secret',
                'activated_at',
                'last_validated_at'
            ]);
        });
    }
};
