<?php

namespace App\Models;

use App\Enums\SubscriptionStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Subscription extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'invoice_item_id',
        'package_id',
        'package_name',
        'status',
        'start_date',
        'expiry_date',
    ];

    protected function casts(): array
    {
        return [
            'status' => SubscriptionStatus::class,
            'start_date' => 'date',
            'expiry_date' => 'date',
        ];
    }

    // ─── Relationships ─────────────────────────────────────

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function invoiceItem(): BelongsTo
    {
        return $this->belongsTo(InvoiceItem::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(Package::class);
    }

    public function licenseTokens(): HasMany
    {
        return $this->hasMany(LicenseToken::class);
    }

    // ─── Scopes ────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', SubscriptionStatus::ACTIVE);
    }

    public function scopeExpired($query)
    {
        return $query->where('status', SubscriptionStatus::EXPIRED);
    }

    // ─── Helpers ───────────────────────────────────────────

    public function isActive(): bool
    {
        return $this->status === SubscriptionStatus::ACTIVE;
    }

    public function isExpired(): bool
    {
        return $this->status === SubscriptionStatus::EXPIRED
            || $this->expiry_date->isPast();
    }

    /**
     * Hitung sisa hari subscription.
     */
    public function remainingDays(): int
    {
        if ($this->expiry_date->isPast()) {
            return 0;
        }

        return (int) now()->diffInDays($this->expiry_date, false);
    }
}
