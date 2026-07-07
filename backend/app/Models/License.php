<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class License extends Model
{
    protected $fillable = [
        'tenant_id',
        'subscription_id',
        'license_key',
        'device_id',
        'device_limit',
        'device_count',
        'server_secret',
        'status',
        'activated_at',
        'last_validated_at',
        'expires_at',
        'user_id',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'activated_at' => 'datetime',
        'last_validated_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function tenant()
    {
        return $this->belongsTo(Tenant::class);
    }

    public function subscription()
    {
        return $this->belongsTo(Subscription::class);
    }

    public function devices()
    {
        return $this->hasMany(Device::class);
    }
}
