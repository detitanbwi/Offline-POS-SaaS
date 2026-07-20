<?php

namespace Database\Seeders;

use App\Models\Package;
use Illuminate\Database\Seeder;

class PackageSeeder extends Seeder
{
    public function run(): void
    {
        $packages = [
            [
                'name' => 'Paket Pro Premium POS',
                'slug' => 'pro-premium',
                'price' => 1200000,
                'default_duration_days' => 365,
                'device_limit_per_token' => 1,
                'description' => 'Paket Pro Premium 1 Tahun untuk mesin kasir utama.',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'name' => 'Paket Basic Lite POS',
                'slug' => 'basic-lite',
                'price' => 600000,
                'default_duration_days' => 180,
                'device_limit_per_token' => 1,
                'description' => 'Paket Basic Lite 6 Bulan untuk tablet tambahan antrean/dapur.',
                'is_active' => true,
                'sort_order' => 2,
            ],
            [
                'name' => 'Paket Basic POS',
                'slug' => 'basic',
                'price' => 150000,
                'default_duration_days' => 30,
                'device_limit_per_token' => 1,
                'description' => 'Paket dasar bulanan untuk 1 perangkat kasir.',
                'is_active' => true,
                'sort_order' => 3,
            ],
            [
                'name' => 'Paket Pro POS',
                'slug' => 'pro',
                'price' => 350000,
                'default_duration_days' => 365,
                'device_limit_per_token' => 1,
                'description' => 'Paket profesional tahunan untuk usaha menengah.',
                'is_active' => true,
                'sort_order' => 4,
            ],
        ];

        foreach ($packages as $data) {
            Package::updateOrCreate(
                ['slug' => $data['slug']],
                $data
            );
        }
    }
}
