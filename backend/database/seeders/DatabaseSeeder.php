<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Create admin user
        User::updateOrCreate(
            ['email' => 'admin@possaas.com'],
            [
                'name' => 'Admin POS SaaS',
                'password' => Hash::make('password'),
                'is_admin' => true,
            ]
        );

        // Seed packages
        $this->call([
            PackageSeeder::class,
        ]);
    }
}
