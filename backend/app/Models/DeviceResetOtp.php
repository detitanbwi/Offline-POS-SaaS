<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeviceResetOtp extends Model
{
    protected $fillable = [
        'email',
        'token_key',
        'otp_code',
        'attempts',
        'is_verified',
        'expires_at',
    ];

    protected $casts = [
        'is_verified' => 'boolean',
        'expires_at' => 'datetime',
    ];
}
