<?php

namespace App\Enums;

enum TokenStatus: string
{
    case AVAILABLE = 'available';
    case ACTIVE = 'active';
    case EXPIRED = 'expired';
    case REVOKED = 'revoked';

    public function label(): string
    {
        return match ($this) {
            self::AVAILABLE => 'Tersedia',
            self::ACTIVE => 'Aktif',
            self::EXPIRED => 'Kedaluwarsa',
            self::REVOKED => 'Dicabut',
        };
    }

    public function badgeClass(): string
    {
        return match ($this) {
            self::AVAILABLE => 'badge-info',
            self::ACTIVE => 'badge-success',
            self::EXPIRED => 'badge-danger',
            self::REVOKED => 'badge-danger',
        };
    }
}
