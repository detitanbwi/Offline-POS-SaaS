# Perbandingan Alur Sistem (Saat Ini vs Usulan Perbaikan)

Berikut adalah flowchart yang menggambarkan perbedaan alur kerja antara sistem yang berjalan saat ini dengan usulan arsitektur yang lebih ketat (*strict*) untuk menangani lisensi, tagihan, dan batas perangkat.

## 1. Alur Sistem Saat Ini (Terdapat Celah)

Pada sistem saat ini, setiap pembayaran tagihan (invoice) akan selalu membuat langganan baru. Selain itu, terdapat fitur "Generate License" yang memungkinkan admin membuat token baru secara bebas tanpa terikat pada tagihan (bisa menyebabkan kebocoran kuota).

```mermaid
graph TD
    classDef danger fill:#fee,stroke:#f66,stroke-width:2px,color:#900;
    classDef standard fill:#f9f9f9,stroke:#333,stroke-width:1px;

    subgraph NormalFlow ["Alur Pembayaran Normal"]
        A["Admin Buat Invoice"] --> B["Invoice UNPAID"]
        B -->|"Admin Approve Pembayaran"| C["Invoice PAID"]
        C --> D["Selalu Buat Subscription Baru"]
        D --> E["Generate Token Baru sejumlah Qty"]
    end

    subgraph SpecialFlow ["Skenario Khusus (Renewal / Perangkat Rusak)"]
        F["Pengguna Ingin Perpanjang Langganan"] --> A
        E -.->|"Token Baru Bertumpuk dengan Token Lama"| G(("Banyak Token Tak Terpakai"))
        
        H["Perangkat Kasir Rusak/Hilang"] -->|"Admin Ingin Akses Cepat"| I("Klik Generate License Manual")
        I --> J["Cetak Token Baru Secara Bebas"]
        J -.-> K(("Kebocoran Kuota Lisensi")):::danger
    end
    
    class A,B,C,D,E standard;
    class F,H,I,J standard;
```

## 2. Saran Alur Sistem Baru (Terkontrol & Aman)

Pada usulan alur ini, kita memisahkan niat pembelian menjadi **Renewal** (Perpanjang masa aktif tanpa tambah perangkat) dan **Add-on** (Tambah perangkat baru). Selain itu, untuk masalah perangkat rusak, admin tidak diperbolehkan mencetak token baru, melainkan me-*reset* token lama.

```mermaid
graph TD
    classDef success fill:#efe,stroke:#6f6,stroke-width:2px,color:#050;
    classDef warning fill:#ffe,stroke:#fc0,stroke-width:2px,color:#640;
    classDef standard fill:#f9f9f9,stroke:#333,stroke-width:1px;

    A["Admin Buat Invoice"] --> B{"Jenis Transaksi?"}
    
    subgraph FlowBeli ["Alur Pembelian Berjenjang"]
        B -->|"1. Beli Baru / Tambah Device"| C["Invoice PAID"]
        C --> D["Update Subscription: Tambah 'Device Quota'"]
        D --> E["Generate Token Baru Sesuai Tambahan Qty"]
        
        B -->|"2. Perpanjang (Renewal)"| F["Invoice PAID"]
        F --> G["Update Subscription: Perpanjang Expiry Date"]
        G --> H["Update Expiry Date pada Token-token Lama"]
    end

    subgraph FlowRusak ["Skenario Khusus (Perangkat Rusak)"]
        I["Perangkat Kasir Rusak/Hilang"] -->|"Harus Gunakan Alur Reset"| J("Admin: Revoke / Reset Device")
        J --> K["Hapus Device Fingerprint dari Token"]
        K --> L["Status Token Kembali AVAILABLE"]
        L -.-> M(("Kuota Tetap Terjaga / Aman")):::success
        
        N["Admin Coba Generate Token Manual"] --> O{"Cek Limit: Total Token < Quota?"}
        O -->|"Ya"| P["Izinkan Generate Token"]
        O -->|"Tidak"| Q["Tolak: Minta Admin Buat Invoice Add-on"]:::warning
    end

    class A,B,C,D,E,F,G,H,I,J,K,L,N,O,P standard;
```

### Penjelasan Perbaikan Kunci:
1. **Atribut `Device Quota`**: Langganan kini memiliki batasan kuota. Token tidak bisa dibuat melebihi batas yang sudah dibayar.
2. **Renewal vs Add-on**: Perpanjangan waktu langganan tidak lagi melahirkan token-token baru yang membuat pangkalan data menjadi kotor (*redundant*).
3. **Mekanisme Reset**: Menghilangkan kebiasaan *bypass* pembuatan token baru. Cukup hapus *binding* alat kasir yang lama, sehingga *Token Key* yang sama bisa dipakai di alat pengganti tanpa merusak limit lisensi.
