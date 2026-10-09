# Egg Gym Platform

Sistem informasi layanan gym terintegrasi untuk **Egg Gym Pontianak** (147+ anggota aktif), menggantikan pencatatan manual (buku tulis & Excel) dengan platform digital multi-peran: **Guest, Member, Personal Trainer, dan Admin**.

Dikembangkan sebagai Tugas Akhir (D3 Teknik Informatika, Politeknik Negeri Pontianak), dikerjakan secara individu — mencakup perancangan database, backend API, aplikasi mobile, dan web admin.

## Fitur Utama

- **Manajemen keanggotaan & pembayaran digital** — integrasi payment gateway Pakasir (QRIS & Virtual Account) dengan webhook konfirmasi otomatis
- **Booking sesi Personal Trainer**
- **Program latihan terstruktur** dengan sistem *progressive unlock*
- **Tracking progres fisik anggota** (foto before/after)
- **Manajemen data alat gym** beserta panduan gerakan
- **Push notification** real-time (Firebase Cloud Messaging)
- **Audit trail** untuk keamanan data transaksi dan perubahan keanggotaan
- **Akses mode Guest** — info paket, profil PT, dan alat gym tanpa perlu daftar akun

## Screenshot

<!-- Tambahkan screenshot aplikasi mobile & web admin di sini -->
<img width="411" height="757" alt="image" src="https://github.com/user-attachments/assets/d4f16aef-7a79-4faa-9cdc-2435a3ac97b8" />
[home Screen Member]

<img width="417" height="736" alt="image" src="https://github.com/user-attachments/assets/de46253d-8397-4893-9213-4f0a2acbee9a" />
[Halaman Trainer Member]

<img width="828" height="427" alt="image" src="https://github.com/user-attachments/assets/278f4b07-c59a-40fe-8962-2b7c15a5e571" />
[Halaman Dasboard Web Admin]

<img width="848" height="427" alt="image" src="https://github.com/user-attachments/assets/66065e7f-83c4-4459-82c7-86f28e181a01" />
[Halaman Member Web Admin]


## Struktur Repository

egg-gym-platform/
├── mobile/ # Aplikasi Flutter Android (Guest, Member, Personal Trainer)
├── backend/ # REST API & Web Admin Laravel
└── README.md


## Teknologi

| Kategori | Teknologi |
|---|---|
| Mobile | Flutter 3.27 / Dart 3.6 |
| Backend | Laravel 10 / PHP 8.1+ |
| Database | MySQL / MariaDB |
| Autentikasi | Laravel Sanctum |
| Notifikasi | Firebase Cloud Messaging |
| Payment Gateway | Pakasir (QRIS & Virtual Account) |
| Web Server | Nginx / Apache |


## Kontak

Muhammad Naufal Zakwan
[LinkedIn](https://www.linkedin.com/in/muhammad-naufal-zakwan/) · [Email](mailto:naufal1103@gmail.com)
