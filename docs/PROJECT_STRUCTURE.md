# Project Structure & Architecture

Aplikasi POS Offline SaaS ini dikembangkan menggunakan struktur Offline-First dengan arsitektur modern untuk Frontend dan Backend.

---

## 1. Arsitektur Frontend (Flutter)

Frontend menggunakan **Clean Architecture** dengan pendekatan **Feature-First** (fitur-fitur dikelompokkan dalam direktori terpisah). Untuk State Management dan Dependency Injection, aplikasi menggunakan **Riverpod**.

### Struktur Folder Utama
```
frontend/
├── android/               # Konfigurasi native Android (Gradle, Proguard, Manifest)
├── lib/
│   ├── core/              # Utility, widget global, tema, konstanta, database
│   │   ├── constants/     # Warna, tipografi, ukuran spacing, konstanta aplikasi
│   │   ├── database/      # SQLCipher encrypted SQLite helper (pos_database.dart)
│   │   ├── di/            # Dependency Injection providers (providers.dart)
│   │   ├── services/      # Service global (AppLogger, DeviceFingerprintService, dll)
│   │   ├── theme/         # AppTheme light & dark
│   │   └── widgets/       # Reusable components (AppButton, AppCard, dll)
│   ├── features/          # Modul bisnis/fitur aplikasi (Feature-First)
│   │   ├── auth/          # Login, input PIN keamanan, SecureStorageService
│   │   ├── license/       # Aktivasi lisensi, validasi berkala
│   │   ├── menu/          # Main dashboard menu kasir
│   │   ├── pos/           # Transaksi penjualan, keranjang belanja, cetak struk
│   │   ├── printer/       # Pencarian bluetooth printer & konfigurasi
│   │   ├── table/         # Pengaturan meja restoran
│   │   └── tax/           # Pengaturan PPN Pajak
│   └── main.dart          # Entry point utama Flutter
```

---

## 2. Arsitektur Backend (Laravel)

Backend berfungsi sebagai sistem License & Tenant Management Manager pusat untuk multi-tenant POS SaaS.

### Struktur Folder Utama
```
backend/
├── app/
│   ├── Http/
│   │   ├── Controllers/   # Aktivasi API, login, web admin dashboard
│   │   └── Middleware/    # AdminMiddleware untuk proteksi route admin
│   ├── Models/            # Tenant, Subscription, License, Device, AuditLog
│   └── Services/          # LicenseService, AuditService
├── config/                # Konfigurasi sistem (termasuk jwt_secret)
├── database/              # Migrations, seeders, factories
├── routes/
│   ├── api.php            # Endpoint API mobile POS (Sanctum auth, rate limited)
│   └── web.php            # Endpoint Dashboard Web Admin
```

---

## 3. Skema Database SQLite (Frontend)

Database lokal dienkripsi penuh menggunakan **SQLCipher**. Versi database ditingkatkan ke **v3** di Sprint 4 dengan penambahan indeks performa pada tabel:
- `products(kategori_id, status)`
- `transactions(created_at, status, payment_method_id)`
- `transaction_items(transaction_id, produk_id)`
- `orders(table_id, status, created_at)`
- `order_items(order_id, produk_id)`
