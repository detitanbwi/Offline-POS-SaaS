# API Reference Reference

Semua komunikasi API menggunakan tipe data JSON. Request API dilindungi dengan middleware throttle (Rate Limiting).

---

## 1. Authentication

### POST `/api/login`
Digunakan untuk login kasir dan mendapatkan Bearer Token Sanctum.

* **Rate Limit:** 10 requests per minute
* **Request Body:**
```json
{
  "email": "kasir@example.com",
  "password": "password123"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Login berhasil",
  "access_token": "1|abcdef1234567890...",
  "user": {
    "id": 1,
    "name": "Kasir Utama",
    "email": "kasir@example.com"
  }
}
```

---

## 2. Device Activation

### POST `/api/activate`
Menghubungkan lisensi ke fingerprint perangkat ini dan menghasilkan token offline JWT.

* **Rate Limit:** 30 requests per minute
* **Headers:** `Authorization: Bearer <access_token>`
* **Request Body:**
```json
{
  "license_key": "LIC-ABCD-EFGH-IJKL",
  "fingerprint_hash": "a1b2c3d4e5f6... (64-char SHA256)",
  "device_name": "Samsung Galaxy S21",
  "device_model": "SM-G991B",
  "device_brand": "Samsung"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Aktivasi berhasil!",
  "offline_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJsaWNlbnNlX2tleSI6IkxJQy1URVNULTExMSIsImZpbmdlcnByaW50X2hhc2giOiJkdW1teV8xMjMifQ...",
  "expires_at": "2027-07-08T00:00:00.000000Z"
}
```

---

## 3. License Validation

### POST `/api/validate-license`
Validasi online berkala lisensi perangkat yang aktif.

* **Rate Limit:** 30 requests per minute
* **Headers:** `Authorization: Bearer <access_token>`
* **Request Body:**
```json
{
  "license_key": "LIC-ABCD-EFGH-IJKL",
  "fingerprint_hash": "a1b2c3d4e5f6... (64-char SHA256)"
}
```
* **Response (200 OK):**
```json
{
  "success": true,
  "message": "Validasi berhasil!",
  "offline_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": "2027-07-08T00:00:00.000000Z"
}
```
