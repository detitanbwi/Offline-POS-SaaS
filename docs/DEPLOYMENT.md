# Deployment & Production Readiness Guide

Panduan langkah-langkah merilis aplikasi Backend dan Frontend (Android APK) ke lingkungan production.

---

## 1. Backend (Laravel) Deployment

### Persiapan Production .env
1. Matikan debug mode:
   ```env
   APP_ENV=production
   APP_DEBUG=false
   ```
2. Generate app key & JWT secret:
   ```bash
   php artisan key:generate
   # Generate base64 32-bytes JWT Secret
   head -c 32 /dev/urandom | base64
   ```
   Tambahkan ke `.env`:
   ```env
   JWT_SECRET=<hasil_generate_di_atas>
   ```
3. Set password database production yang kuat pada `DB_PASSWORD`.

### Perintah Rilis (CI/CD atau VPS)
```bash
composer install --no-dev --optimize-autoloader
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force
```

---

## 2. Frontend (Android APK) Release

### 1. Generate Keystore Keamanan
Jika belum ada, buat Java Keystore (JKS) baru untuk tanda tangan rilis:
```bash
keytool -genkey -v -keystore android/app/release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

### 2. Konfigurasi `key.properties`
Buat file `frontend/android/key.properties`:
```properties
storePassword=<password_keystore_anda>
keyPassword=<password_key_anda>
keyAlias=key
storeFile=release-key.jks
```

### 3. Build Obfuscated Android App Bundle / APK
Jalankan perintah flutter build dengan parameter obfuscasi kode untuk perlindungan reverse engineering:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
Parameter tambahan:
* `--obfuscate`: Menyembunyikan nama kelas, metode, dan variabel.
* `--split-debug-info`: Menyimpan debug symbols secara terpisah agar ukuran APK lebih kecil dan kode sulit didekompilasi.
* Proguard / R8 akan otomatis aktif sesuai aturan di `android/app/proguard-rules.pro`.
