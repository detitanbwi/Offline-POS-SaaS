<?php

namespace App\Models;

use App\Enums\DeviceStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Device extends Model
{
    use HasUuids;

    protected $fillable = [
        'license_token_id',
        'tenant_id',
        'fingerprint_hash',
        'android_id_hash',
        'manufacturer',
        'brand',
        'model',
        'installation_uuid_hash',
        'status',
        'activated_at',
        'last_validated_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => DeviceStatus::class,
            'activated_at' => 'datetime',
            'last_validated_at' => 'datetime',
        ];
    }

    // ─── Relationships ─────────────────────────────────────

    public function licenseToken(): BelongsTo
    {
        return $this->belongsTo(LicenseToken::class);
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    // ─── Scopes ────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', DeviceStatus::ACTIVE);
    }

    // ─── Helpers ───────────────────────────────────────────

    public function isActive(): bool
    {
        return $this->status === DeviceStatus::ACTIVE;
    }

    /**
     * Label ringkas perangkat.
     */
    public function getDisplayNameAttribute(): string
    {
        $parts = array_filter([$this->brand, $this->model]);

        return implode(' ', $parts) ?: 'Unknown Device';
    }
}
