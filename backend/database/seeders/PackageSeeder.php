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
                'name' => 'Basic',
                'slug' => 'basic',
                'price' => 150000,
                'default_duration_days' => 30,
                'device_limit_per_token' => 1,
                'description' => 'Paket dasar untuk usaha kecil. Cocok untuk satu perangkat kasir.',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'name' => 'Pro',
                'slug' => 'pro',
                'price' => 350000,
                'default_duration_days' => 365,
                'device_limit_per_token' => 1,
                'description' => 'Paket profesional untuk usaha menengah. Langganan tahunan dengan fitur lengkap.',
                'is_active' => true,
                'sort_order' => 2,
            ],
            [
                'name' => 'Enterprise',
                'slug' => 'enterprise',
                'price' => 750000,
                'default_duration_days' => 365,
                'device_limit_per_token' => 1,
                'description' => 'Paket enterprise untuk jaringan toko. Dukungan prioritas dan fitur premium.',
                'is_active' => true,
                'sort_order' => 3,
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
