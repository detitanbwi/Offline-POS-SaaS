<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Device extends Model
{
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'license_id',
        'fingerprint_hash',
        'device_name',
        'device_model',
        'device_brand',
        'status',
        'activated_at',
        'last_validated_at',
    ];

    protected $casts = [
        'activated_at' => 'datetime',
        'last_validated_at' => 'datetime',
    ];

    public function license()
    {
        return $this->belongsTo(License::class);
    }
}
