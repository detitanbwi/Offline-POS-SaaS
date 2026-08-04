<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class PinResetOtp extends Model
{
    protected $fillable = [
        'email',
        'otp_code',
        'reset_token',
        'attempts',
        'is_verified',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'is_verified' => 'boolean',
            'expires_at' => 'datetime',
        ];
    }

    /**
     * Scope untuk mengambil OTP yang masih berlaku (belum expired).
     */
    public function scopeActive(Builder $query): void
    {
        $query->where('expires_at', '>', now());
    }
}
