<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LicenseCheckLog extends Model
{
    use HasUuids;

    protected $fillable = [
        'tenant_id',
        'license_token_id',
        'status',
        'trigger_type',
        'remaining_time_seconds',
    ];

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function licenseToken(): BelongsTo
    {
        return $this->belongsTo(LicenseToken::class);
    }
}
