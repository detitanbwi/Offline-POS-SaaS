<?php

namespace App\Models;

use App\Enums\InvoiceStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Invoice extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'invoice_number',
        'status',
        'subtotal',
        'tax_amount',
        'total_amount',
        'due_date',
        'paid_at',
        'payment_method',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'status' => InvoiceStatus::class,
            'subtotal' => 'decimal:2',
            'tax_amount' => 'decimal:2',
            'total_amount' => 'decimal:2',
            'due_date' => 'date',
            'paid_at' => 'datetime',
        ];
    }

    // ─── Relationships ─────────────────────────────────────

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function subscriptions(): HasManyThrough
    {
        return $this->hasManyThrough(
            Subscription::class,
            InvoiceItem::class,
            'invoice_id',      // FK on invoice_items
            'invoice_item_id', // FK on subscriptions
            'id',              // Local key on invoices
            'id'               // Local key on invoice_items
        );
    }

    // ─── Scopes ────────────────────────────────────────────

    public function scopeUnpaid($query)
    {
        return $query->where('status', InvoiceStatus::UNPAID);
    }

    public function scopePaid($query)
    {
        return $query->where('status', InvoiceStatus::PAID);
    }

    // ─── Helpers ───────────────────────────────────────────

    /**
     * Generate nomor invoice unik: INV-YYYYMMDD-XXXX
     */
    public static function generateInvoiceNumber(): string
    {
        $date = now()->format('Ymd');
        $prefix = "INV-{$date}-";

        $lastInvoice = static::withTrashed()
            ->where('invoice_number', 'like', "{$prefix}%")
            ->orderBy('invoice_number', 'desc')
            ->first();

        if ($lastInvoice) {
            $lastNumber = (int) Str::afterLast($lastInvoice->invoice_number, '-');
            $nextNumber = $lastNumber + 1;
        } else {
            $nextNumber = 1;
        }

        return $prefix.str_pad($nextNumber, 4, '0', STR_PAD_LEFT);
    }

    /**
     * Cek apakah invoice sudah dibayar.
     */
    public function isPaid(): bool
    {
        return $this->status === InvoiceStatus::PAID;
    }

    /**
     * Cek apakah invoice belum dibayar.
     */
    public function isUnpaid(): bool
    {
        return $this->status === InvoiceStatus::UNPAID;
    }

    /**
     * Hitung total dari items.
     */
    public function recalculateTotal(): void
    {
        $subtotal = $this->items()->sum('total_price');
        $this->subtotal = $subtotal;
        $this->total_amount = $subtotal + $this->tax_amount;
        $this->save();
    }
}
