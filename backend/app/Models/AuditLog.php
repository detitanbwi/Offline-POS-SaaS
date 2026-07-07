<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    protected $fillable = [
        'tenant_id',
        'license_id',
        'device_id',
        'user_id',
        'action',
        'details',
        'ip_address',
        'user_agent',
    ];

    public function tenant()
    {
        return $this->belongsTo(Tenant::class);
    }

    public function license()
    {
        return $this->belongsTo(License::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
