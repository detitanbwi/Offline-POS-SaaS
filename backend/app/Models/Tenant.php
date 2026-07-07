<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Tenant extends Model
{
    use HasFactory;

    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'name',
        'owner_name',
        'email',
        'phone',
        'store_name',
        'store_address',
        'status',
    ];

    public function subscriptions()
    {
        return $this->hasMany(Subscription::class);
    }

    public function licenses()
    {
        return $this->hasMany(License::class);
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }
}
