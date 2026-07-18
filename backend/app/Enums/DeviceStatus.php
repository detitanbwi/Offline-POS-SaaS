<?php

namespace App\Enums;

enum DeviceStatus: string
{
    case ACTIVE = 'active';
    case DEACTIVATED = 'deactivated';

    public function label(): string
    {
        return match ($this) {
            self::ACTIVE => 'Aktif',
            self::DEACTIVATED => 'Nonaktif',
        };
    }

    public function badgeClass(): string
    {
        return match ($this) {
            self::ACTIVE => 'badge-success',
            self::DEACTIVATED => 'badge-danger',
        };
    }
}
