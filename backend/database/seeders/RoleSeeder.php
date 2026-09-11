<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Define all permissions
        $permissions = [
            // Dashboard
            ['slug' => 'dashboard.view', 'name' => 'Lihat Dashboard', 'module' => 'dashboard', 'description' => 'Melihat ringkasan statistik dashboard'],

            // Profile
            ['slug' => 'profile.edit', 'name' => 'Edit Profil Admin', 'module' => 'profile', 'description' => 'Mengubah informasi profil & password sendiri'],

            // Tenants
            ['slug' => 'tenants.view', 'name' => 'Lihat Daftar Tenant', 'module' => 'tenants', 'description' => 'Melihat list dan detail tenant'],
            ['slug' => 'tenants.create', 'name' => 'Tambah Tenant', 'module' => 'tenants', 'description' => 'Mendaftarkan tenant baru'],
            ['slug' => 'tenants.edit', 'name' => 'Edit Data Tenant', 'module' => 'tenants', 'description' => 'Mengubah informasi tenant'],
            ['slug' => 'tenants.suspend', 'name' => 'Suspend / Nonaktifkan Tenant', 'module' => 'tenants', 'description' => 'Menonaktifkan akses tenant'],
            ['slug' => 'tenants.reactivate', 'name' => 'Reaktivasi Tenant', 'module' => 'tenants', 'description' => 'Mengaktifkan kembali tenant'],
            ['slug' => 'tenants.generate_license', 'name' => 'Generate License Tenant', 'module' => 'tenants', 'description' => 'Membuat token lisensi langsung dari tenant'],
            ['slug' => 'tenants.delete', 'name' => 'Hapus Tenant', 'module' => 'tenants', 'description' => 'Menghapus data tenant dari sistem'],

            // Packages
            ['slug' => 'packages.view', 'name' => 'Lihat Paket', 'module' => 'packages', 'description' => 'Melihat daftar paket langganan'],
            ['slug' => 'packages.create', 'name' => 'Tambah Paket', 'module' => 'packages', 'description' => 'Menambah paket langganan baru'],
            ['slug' => 'packages.edit', 'name' => 'Edit Paket', 'module' => 'packages', 'description' => 'Mengubah tarif & durasi paket'],
            ['slug' => 'packages.delete', 'name' => 'Hapus Paket', 'module' => 'packages', 'description' => 'Menghapus paket langganan'],

            // Invoices
            ['slug' => 'invoices.view', 'name' => 'Lihat Tagihan / Invoice', 'module' => 'invoices', 'description' => 'Melihat list invoice & laporan'],
            ['slug' => 'invoices.report', 'name' => 'Laporan Rekap Invoice', 'module' => 'invoices', 'description' => 'Melihat dan mengekspor laporan rekap invoice'],
            ['slug' => 'invoices.create', 'name' => 'Buat Tagihan Baru', 'module' => 'invoices', 'description' => 'Membuat invoice baru untuk tenant'],
            ['slug' => 'invoices.upload_proof', 'name' => 'Upload Bukti Pembayaran', 'module' => 'invoices', 'description' => 'Mengunggah bukti transfer'],
            ['slug' => 'invoices.mark_paid', 'name' => 'Konfirmasi Lunas Invoice', 'module' => 'invoices', 'description' => 'Menyetujui pembayaran invoice'],
            ['slug' => 'invoices.cancel', 'name' => 'Batalkan Invoice', 'module' => 'invoices', 'description' => 'Membatalkan invoice yang belum lunas'],
            ['slug' => 'invoices.download_pdf', 'name' => 'Unduh PDF Invoice', 'module' => 'invoices', 'description' => 'Mengunduh invoice dalam format PDF'],

            // Users & RBAC
            ['slug' => 'users.view', 'name' => 'Lihat Daftar Pengguna', 'module' => 'users', 'description' => 'Melihat list pengguna admin & role'],
            ['slug' => 'users.create', 'name' => 'Tambah Pengguna', 'module' => 'users', 'description' => 'Mendaftarkan akun staf/admin baru'],
            ['slug' => 'users.edit', 'name' => 'Edit Pengguna & Role', 'module' => 'users', 'description' => 'Mengubah nama, email, role dan password pengguna'],
            ['slug' => 'users.delete', 'name' => 'Hapus Pengguna', 'module' => 'users', 'description' => 'Menghapus akun pengguna dari sistem'],

            // Subscriptions
            ['slug' => 'subscriptions.view', 'name' => 'Lihat Langganan Aktif', 'module' => 'subscriptions', 'description' => 'Melihat masa aktif & status langganan'],

            // License Tokens
            ['slug' => 'tokens.view', 'name' => 'Lihat Token Lisensi', 'module' => 'tokens', 'description' => 'Melihat daftar token lisensi'],
            ['slug' => 'tokens.reset_device', 'name' => 'Reset ID Perangkat / Device', 'module' => 'tokens', 'description' => 'Melepaskan binding hardware ID perangkat kasir'],
            ['slug' => 'tokens.revoke', 'name' => 'Cabut / Revoke Token Lisensi', 'module' => 'tokens', 'description' => 'Mencabut token lisensi yang sedang aktif'],

            // Devices
            ['slug' => 'devices.view', 'name' => 'Lihat Perangkat Terdaftar', 'module' => 'devices', 'description' => 'Melihat riwayat & status perangkat kasir'],

            // Audit Logs
            ['slug' => 'audit_logs.view', 'name' => 'Lihat Audit Log', 'module' => 'audit_logs', 'description' => 'Melihat riwayat jejak aktivitas admin'],
        ];

        $createdPermissions = [];
        foreach ($permissions as $perm) {
            $createdPermissions[$perm['slug']] = Permission::updateOrCreate(
                ['slug' => $perm['slug']],
                $perm
            );
        }

        // 2. Create Roles
        $superAdminRole = Role::updateOrCreate(
            ['slug' => 'super_admin'],
            [
                'name' => 'Super Admin',
                'description' => 'Wewenang penuh 100% atas seluruh modul & konfigurasi sistem',
            ]
        );

        $operatorRole = Role::updateOrCreate(
            ['slug' => 'operator'],
            [
                'name' => 'Operator',
                'description' => 'Akses operasional harian terbatas (tanpa hak reset perangkat, delete/suspend tenant, dan kelola paket)',
            ]
        );

        // 3. Assign permissions to Super Admin (All)
        $superAdminRole->permissions()->sync(
            collect($createdPermissions)->pluck('id')->toArray()
        );

        // 4. Assign restricted permissions to Operator
        $operatorPermissionSlugs = [
            'dashboard.view',
            'profile.edit',
            'tenants.view',
            'tenants.create',
            'tenants.edit',
            'tenants.generate_license',
            'packages.view',
            'invoices.view',
            'invoices.create',
            'invoices.upload_proof',
            'invoices.download_pdf',
            'subscriptions.view',
            'tokens.view',
            'devices.view',
            'audit_logs.view',
        ];

        $operatorPermissionIds = collect($operatorPermissionSlugs)
            ->filter(fn ($slug) => isset($createdPermissions[$slug]))
            ->map(fn ($slug) => $createdPermissions[$slug]->id)
            ->values()
            ->toArray();

        $operatorRole->permissions()->sync($operatorPermissionIds);

        // 5. Update existing admin user to Super Admin role
        $adminUser = User::where('email', 'admin@possaas.com')->first();
        if ($adminUser) {
            $adminUser->update([
                'role_id' => $superAdminRole->id,
                'is_admin' => true,
            ]);
        }

        // 6. Create demo operator user
        User::updateOrCreate(
            ['email' => 'operator@possaas.com'],
            [
                'name' => 'Operator Staff',
                'password' => Hash::make('password'),
                'is_admin' => true,
                'role_id' => $operatorRole->id,
            ]
        );
    }
}
