# Developer Onboarding & Contribution Guide

Panduan bagi pengembang baru untuk melakukan setup lokal, testing, dan berkontribusi pada pengembangan POS Offline SaaS.

---

## 1. Persyaratan Sistem Lokal
- Flutter SDK (v3.22.0 atau lebih tinggi)
- PHP (v8.3 atau lebih tinggi)
- Composer (v2.x)
- MySQL / MariaDB (Untuk database backend lokal)

---

## 2. Setup Awal Pengembangan

### Backend
1. Clone repositori ini.
2. Salin `.env.example` menjadi `.env` dan konfigurasikan koneksi MySQL lokal.
3. Jalankan instalasi composer:
   ```bash
   composer install
   ```
4. Generate key & migrasikan database beserta seeders default:
   ```bash
   php artisan key:generate
   php artisan migrate:fresh --seed
   ```
5. Jalankan server lokal:
   ```bash
   php artisan serve
   ```

### Frontend
1. Masuk ke direktori `frontend`.
2. Dapatkan dependensi Flutter:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi pada simulator/perangkat debug:
   ```bash
   flutter run
   ```

---

## 3. Menjalankan Automated Tests

Selalu pastikan seluruh pengujian berhasil sebelum mengirimkan Pull Request / Merge Request.

### Menguji Backend (PHPUnit)
```bash
vendor/bin/phpunit --configuration=phpunit.xml
```

### Menguji Frontend (Flutter Test)
```bash
flutter test
```
Atau hanya unit tests:
```bash
flutter test test/unit/
```

---

## 4. Standar Penulisan Kode & SOLID
- **Clean Architecture & SOLID:** Selalu pisahkan domain model, data repository, dan state notifier presentation logic.
- **Dependency Injection:** Jangan instansiasi service atau repository secara manual di dalam widget atau screen. Gunakan Riverpod `ref.watch` atau `ref.read` dari `providers.dart`.
- **Enums & Konstanta:** Hindari penggunaan magic strings untuk status order/transaksi. Gunakan kelas konstanta yang didefinisikan di `lib/core/constants/app_constants.dart`.
