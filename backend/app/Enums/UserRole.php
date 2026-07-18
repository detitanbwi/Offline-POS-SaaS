<?php

namespace App\Enums;

enum UserRole: string
{
    case OWNER = 'owner';
    case CASHIER = 'cashier';

    public function label(): string
    {
        return match ($this) {
            self::OWNER => 'Pemilik',
            self::CASHIER => 'Kasir',
        };
    }
}
