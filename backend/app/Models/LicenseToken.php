<?php

namespace App\Models;

use App\Enums\TokenStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class LicenseToken extends Model
{
    use HasUuids;

    protected $fillable = [
        'subscription_id',
        'tenant_id',
        'token_key',
        'server_secret',
        'status',
        'activated_at',
        'last_validated_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => TokenStatus::class,
            'activated_at' => 'datetime',
            'last_validated_at' => 'datetime',
        ];
    }

    // ─── Relationships ─────────────────────────────────────

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class);
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function device(): HasOne
    {
        return $this->hasOne(Device::class);
    }

    // ─── Scopes ────────────────────────────────────────────

    public function scopeAvailable($query)
    {
        return $query->where('status', TokenStatus::AVAILABLE);
    }

    public function scopeActive($query)
    {
        return $query->where('status', TokenStatus::ACTIVE);
    }

    // ─── Helpers ───────────────────────────────────────────

    public function isAvailable(): bool
    {
        return $this->status === TokenStatus::AVAILABLE;
    }

    public function isActive(): bool
    {
        return $this->status === TokenStatus::ACTIVE;
    }

    public function isUsable(): bool
    {
        return in_array($this->status, [TokenStatus::AVAILABLE, TokenStatus::ACTIVE]);
    }

    /**
     * Generate token key yang aman dan tidak dapat ditebak.
     * Format: POS-{PKG}-XXXX-XXXX-XXXX
     *
     * Menggunakan random_bytes() untuk keamanan kriptografis.
     */
    public static function generateTokenKey(string $packagePrefix = 'GEN'): string
    {
        $segment = function () {
            // Gunakan random_bytes untuk keamanan, lalu encode ke alfanumerik uppercase
            $bytes = random_bytes(3);
            $hex = strtoupper(bin2hex($bytes));

            return substr($hex, 0, 4);
        };

        $prefix = strtoupper(substr($packagePrefix, 0, 3));

        return "POS-{$prefix}-{$segment()}-{$segment()}-{$segment()}";
    }

    /**
     * Generate server secret yang aman.
     */
    public static function generateServerSecret(): string
    {
        return bin2hex(random_bytes(32));
    }
}
