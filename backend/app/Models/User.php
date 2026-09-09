<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'password',
        'pin',
        'tenant_id',
        'role_id',
        'is_admin',
    ];

    protected $hidden = [
        'password',
        'pin',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    public function isSuperAdmin(): bool
    {
        if (! $this->is_admin) {
            return false;
        }

        if (! empty($this->role_id)) {
            $role = $this->role ?? Role::find($this->role_id);
            return $role?->slug === 'super_admin';
        }

        return true;
    }

    public function hasRole(string|array $roles): bool
    {
        $role = $this->role ?? ($this->role_id ? Role::find($this->role_id) : null);
        if (! $role) {
            return false;
        }

        if (is_array($roles)) {
            return in_array($role->slug, $roles);
        }

        return $role->slug === $roles;
    }

    public function hasPermission(string $permissionSlug): bool
    {
        if (! $this->is_admin) {
            return false;
        }

        if ($this->isSuperAdmin()) {
            return true;
        }

        $role = $this->role ?? ($this->role_id ? Role::find($this->role_id) : null);
        if (! $role) {
            return false;
        }

        return $role->hasPermission($permissionSlug);
    }
}
