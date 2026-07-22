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
                'name' => 'Paket Basic POS (1 Bulan)',
                'slug' => 'basic-1-bulan',
                'price' => 150000,
                'validity_type' => 'duration',
                'default_duration_days' => 30,
                'device_limit_per_token' => 1,
                'description' => 'Paket dasar bulanan untuk 1 perangkat kasir.',
                'is_active' => true,
            ],
            [
                'name' => 'Paket Pro POS (3 Bulan)',
                'slug' => 'pro-3-bulan',
                'price' => 400000,
                'validity_type' => 'duration',
                'default_duration_days' => 90,
                'device_limit_per_token' => 1,
                'description' => 'Paket 3 bulan untuk usaha berkembang.',
                'is_active' => true,
            ],
            [
                'name' => 'Paket Pro Lite (6 Bulan)',
                'slug' => 'pro-6-bulan',
                'price' => 750000,
                'validity_type' => 'duration',
                'default_duration_days' => 180,
                'device_limit_per_token' => 1,
                'description' => 'Paket 6 bulan hemat untuk 1 perangkat kasir.',
                'is_active' => true,
            ],
            [
                'name' => 'Paket Enterprise POS (1 Tahun)',
                'slug' => 'enterprise-1-tahun',
                'price' => 1350000,
                'validity_type' => 'duration',
                'default_duration_days' => 365,
                'device_limit_per_token' => 1,
                'description' => 'Paket profesional tahunan terbaik.',
                'is_active' => true,
            ],
            [
                'name' => 'Paket Promo Akhir Tahun (Fixed Date)',
                'slug' => 'promo-akhir-tahun',
                'price' => 990000,
                'validity_type' => 'fixed_date',
                'default_duration_days' => null,
                'end_date' => '2026-12-30',
                'device_limit_per_token' => 1,
                'description' => 'Paket promo spesial berlaku hingga 30 Desember 2026.',
                'is_active' => true,
            ],
            [
                'name' => 'Paket Season Pass (Range Waktu)',
                'slug' => 'season-pass-2026',
                'price' => 1100000,
                'validity_type' => 'date_range',
                'default_duration_days' => null,
                'start_date' => '2026-01-01',
                'end_date' => '2026-12-31',
                'device_limit_per_token' => 1,
                'description' => 'Paket musim tertentu berlaku 01 Jan 2026 s/d 31 Des 2026.',
                'is_active' => true,
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
