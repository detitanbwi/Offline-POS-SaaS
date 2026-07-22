<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Package extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'slug',
        'price',
        'validity_type',
        'default_duration_days',
        'start_date',
        'end_date',
        'device_limit_per_token',
        'description',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'default_duration_days' => 'integer',
            'device_limit_per_token' => 'integer',
            'is_active' => 'boolean',
            'start_date' => 'date',
            'end_date' => 'date',
        ];
    }

    public function invoiceItems(): HasMany
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    /**
     * Scope: hanya paket yang aktif.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope: urut berdasarkan nama.
     */
    public function scopeOrdered($query)
    {
        return $query->orderBy('name');
    }

    /**
     * Hitung tanggal mulai dan kedaluwarsa subscription berdasarkan tipe masa berlaku paket.
     */
    public function calculateSubscriptionDates(?Carbon $customStartDate = null): array
    {
        $startDate = $customStartDate ? $customStartDate->copy() : Carbon::today();

        if ($this->validity_type === 'date_range') {
            $start = $this->start_date ? Carbon::parse($this->start_date) : $startDate;
            $expiry = $this->end_date ? Carbon::parse($this->end_date) : $start->copy()->addDays(30);

            return [
                'start_date' => $start->toDateString(),
                'expiry_date' => $expiry->toDateString(),
            ];
        }

        if ($this->validity_type === 'fixed_date') {
            $expiry = $this->end_date ? Carbon::parse($this->end_date) : $startDate->copy()->addDays(30);

            return [
                'start_date' => $startDate->toDateString(),
                'expiry_date' => $expiry->toDateString(),
            ];
        }

        // Default: 'duration'
        $days = (int) ($this->default_duration_days ?? 30);

        return [
            'start_date' => $startDate->toDateString(),
            'expiry_date' => $startDate->copy()->addDays($days)->toDateString(),
        ];
    }

    /**
     * Generate slug otomatis dari nama paket.
     */
    public static function generateSlug(string $name): string
    {
        return strtolower(preg_replace('/[^a-zA-Z0-9]+/', '-', trim($name)));
    }

    /**
     * Mendapatkan kode singkat paket untuk format token.
     * Contoh: "Pro Package" → "PRO", "Basic" → "BAS", "Enterprise" → "ENT"
     */
    public function getTokenPrefix(): string
    {
        $words = explode(' ', $this->name);
        $first = strtoupper(substr($words[0], 0, 3));

        return $first;
    }
}
