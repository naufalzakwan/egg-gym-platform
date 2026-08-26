# Egg Gym Platform

Repository gabungan sistem informasi layanan Egg Gym Pontianak. Repository ini memuat aplikasi mobile Flutter untuk Member dan Personal Trainer serta backend Laravel yang menyediakan REST API dan Web Admin.

## Struktur Repository

```text
egg-gym-platform/
|-- mobile/    # Aplikasi Flutter Android
|-- backend/   # REST API dan Web Admin Laravel
`-- README.md
```

## Teknologi

- Flutter 3.27 / Dart 3.6
- Laravel 10 / PHP 8.1+
- MySQL atau MariaDB
- Nginx atau Apache
- Laravel Sanctum
- Firebase Cloud Messaging
- Pakasir payment gateway

## Informasi Akses Setelah Deployment

- Web Admin: `https://DOMAIN-VPS/admin/login`
- API: `https://DOMAIN-VPS/api/v1`
- Dokumen root: arahkan virtual host ke `backend/public`, bukan ke root repository.

Akun demo tersedia setelah menjalankan seeder:

| Peran | Email | Password | Akses |
| --- | --- | --- | --- |
| Admin | `admin@egggym.com` | `admin12345` | Web Admin |
| Member | `member@egggym.com` | `member12345` | Aplikasi mobile |
| Personal Trainer | `adrian@egggym.com` | `trainer12345` | Aplikasi mobile |

Ganti seluruh password demo sebelum sistem production digunakan.

## Deployment Backend ke VPS

### Kebutuhan Server

- Linux VPS
- PHP 8.1 atau lebih baru beserta ekstensi umum Laravel, MySQL, cURL, Mbstring, XML, ZIP, GD, dan BCMath
- Composer 2
- MySQL 8 atau MariaDB
- Nginx atau Apache
- Node.js 18+ dan npm untuk membangun aset Vite
- Cron
- HTTPS/SSL

### Instalasi

Jalankan dari folder `backend`:

```bash
composer install --no-dev --optimize-autoloader
npm ci
npm run build
cp .env.example .env
php artisan key:generate
```

Isi `.env` menggunakan konfigurasi production dan kredensial yang diberikan melalui jalur privat. Setelah database dibuat dan `.env` dikonfigurasi, jalankan:

```bash
php artisan migrate --force
php artisan db:seed --force
php artisan storage:link
php artisan optimize
```

Jangan menjalankan `migrate:fresh` pada production karena perintah tersebut menghapus seluruh data.

Berikan hak tulis kepada user web server untuk folder berikut:

```text
backend/storage
backend/bootstrap/cache
```

### Scheduler

Tambahkan satu cron entry agar booking kedaluwarsa, pengingat, jadwal trainer, dan proses terjadwal lain tetap berjalan:

```cron
* * * * * cd /PATH/egg-gym-platform/backend && php artisan schedule:run >> /dev/null 2>&1
```

### Nginx

Konfigurasi virtual host harus menggunakan folder berikut sebagai document root:

```text
/PATH/egg-gym-platform/backend/public
```

Pastikan semua request yang tidak menunjuk berkas statis diteruskan ke `index.php`, lalu aktifkan HTTPS. Jangan mengekspos `.env`, folder repository `.git`, atau kredensial Firebase melalui web server.

## Konfigurasi Environment Production

Nilai minimal yang perlu diisi pada `backend/.env`:

```dotenv
APP_NAME="Egg Gym"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://DOMAIN-VPS

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=egg_gym
DB_USERNAME=egg_gym
DB_PASSWORD=GANTI_DENGAN_PASSWORD_KUAT

SESSION_SECURE_COOKIE=true

PAKASIR_BASE_URL=https://app.pakasir.com
PAKASIR_PROJECT=ISI_PROJECT_PAKASIR
PAKASIR_API_KEY=ISI_API_KEY_PAKASIR
PAKASIR_TIMEOUT=20

FCM_PROJECT_ID=ISI_FIREBASE_PROJECT_ID
FCM_SERVICE_ACCOUNT_PATH=/PATH/PRIVATE/firebase-service-account.json
FCM_TIMEOUT=15
```

File Firebase service account wajib disimpan langsung di VPS pada lokasi privat dan tidak boleh dimasukkan ke Git.

## Build Aplikasi Mobile untuk Production

Backend harus memiliki domain HTTPS yang sudah aktif sebelum APK production dibuat. Jalankan dari folder `mobile`:

```bash
flutter pub get
flutter build apk --release --dart-define=BACKEND_BASE_URL=https://DOMAIN-VPS
```

Hasil APK tersedia di:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Konfigurasi Firebase Android `mobile/android/app/google-services.json` dan signing key release diberikan melalui jalur privat karena tidak disimpan dalam repository.

## Verifikasi Deployment

Setelah deployment, periksa:

```bash
php artisan about
php artisan migrate:status
php artisan schedule:list
```

Kemudian lakukan pemeriksaan berikut:

1. Buka `https://DOMAIN-VPS/admin/login`.
2. Pastikan login Admin berhasil.
3. Pastikan endpoint publik dapat diakses, misalnya `https://DOMAIN-VPS/api/v1/public/membership-plans`.
4. Build APK dengan `BACKEND_BASE_URL` domain production.
5. Uji login Member dan Personal Trainer dari jaringan seluler, bukan hanya Wi-Fi VPS.
6. Uji upload gambar, checkout Pakasir, webhook pembayaran, scheduler, dan push notification.

## Berkas yang Diberikan Terpisah

Berkas berikut tidak disimpan di repository dan harus diberikan kepada pengelola VPS melalui media privat:

- Nilai `.env` production, termasuk database dan Pakasir
- Firebase service account backend
- `google-services.json` untuk build Android
- Keystore Android release beserta alias dan password jika APK akan ditandatangani untuk distribusi
- Akses domain, DNS, dan kredensial server yang memang diperlukan

Jangan mengirim kredensial melalui issue, commit, atau README GitHub.
