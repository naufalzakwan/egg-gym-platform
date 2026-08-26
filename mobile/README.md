# EggGym Mobile App

Project Flutter untuk sistem informasi layanan gym EggGym Pontianak.

Fokus tahap saat ini:
- membangun UI kit mobile dulu
- memakai clean architecture dasar
- state management dengan `Provider`
- routing dan flow halaman dengan `GetX`
- menyiapkan demo yang enak dilihat di HP

## Referensi

- PRD: `PRD_EggGym.docx`
- Proposal: `Proposal Tugas Akhir Muhammad Naufal Zakwan 6E.doc`
- Figma: `EGG GYM APP`
- ERD rekomendasi progres fisik: `docs/member_progress_erd.md`
- Roadmap backend dan admin web: `docs/backend_admin_web_roadmap.md`
- ERD inti backend: `docs/backend_core_erd.md`
- Kontrak endpoint API mobile: `docs/mobile_api_contract.md`
- Checklist setup backend Laravel: `docs/backend_setup_checklist.md`
- Struktur repo backend Laravel: `docs/backend_repo_structure.md`
- Breakdown migration Laravel: `docs/backend_migration_breakdown.md`
- Panduan eksekusi bootstrap backend Laravel: `docs/backend_bootstrap_execution.md`

## Status Saat Ini

Status umum:
- `UI Demo Foundation` sudah dibuat
- `Task tracker` sudah ada di dalam app
- `Detail screens demo` untuk member dan trainer sudah mulai tersedia
- `Backend integration` belum dikerjakan
- `Detail feature screens` masih bertahap

## Checklist Progress

### Sudah Selesai

- [x] Setup struktur clean architecture dasar: `app`, `core`, `data`, `domain`, `presentation`
- [x] Setup `Provider` untuk state utama demo
- [x] Setup `GetX` untuk routing dan shell page
- [x] Setup theme EggGym gelap dengan aksen gold
- [x] Splash screen
- [x] Login screen
- [x] Guest public explorer
- [x] Member shell dengan 5 tab
- [x] Trainer shell dengan 5 tab
- [x] Timer demo untuk member
- [x] Timer demo untuk personal trainer
- [x] In-app task board untuk lihat status pengerjaan
- [x] Mock repository dan local demo data untuk kebutuhan presentasi
- [x] Program detail tracker screen untuk demo member
- [x] Membership packages screen untuk preview paket
- [x] PT session detail screen untuk demo trainer
- [x] Client detail screen untuk flow trainer
- [x] Payment checkout screen dan payment success flow untuk demo membership
- [x] Booking confirmation screen dan reschedule flow untuk demo trainer schedule
- [x] Trainer profile detail screen yang lebih lengkap untuk flow guest, member, dan trainer
- [x] Live training session UI untuk flow member dan trainer
- [x] Exercise checklist UI yang lebih interaktif untuk tracker program member
- [x] Legacy cleanup pass 1 untuk guest shell lama dan datasource duplikat
- [x] Critical CTA connection pass 1 untuk booking, update progress, dan live session
- [x] Member physical progress UI untuk before-after checkpoint, histori badan, dan form checkpoint demo
- [x] Equipment detail screen untuk guest dan member
- [x] Placeholder screen cleanup pass 1 untuk member dan trainer
- [x] Placeholder screen cleanup pass 2 untuk trainer program builder dan sinkronisasi screen baru
- [x] Create Program Form untuk flow trainer-member
- [x] Edit Training Session untuk mengelola daftar latihan dalam tiap sesi
- [x] Progressive Unlock Timeline untuk status sesi selesai, aktif, dan terkunci
- [x] Polish Program Detail Tracker untuk memperjelas mode PT read-only dan progres sesi
- [x] Polish Live Training Session untuk memperjelas queue latihan dan status sesi live
- [x] Konsistensi istilah sesi aktif agar flow `Program dari PT` dan `Latihan Mandiri` lebih mudah dipahami saat demo
- [x] Trainer-side progress control untuk update progres PT lalu preview hasil sinkron ke tracker member
- [x] Copy consistency pass untuk flow workout/PT agar istilah dan CTA lebih seragam saat demo
- [x] Roadmap backend + admin web untuk transisi demo ke production
- [x] Finalisasi ERD inti backend untuk auth, booking, program, progress, payment, dan notifikasi
- [x] Susun kontrak endpoint API mobile untuk guest, member, trainer, payment, dan notifikasi dasar
- [x] Checklist teknis setup backend Laravel + Sanctum + role permission
- [x] Susun struktur repo/folder backend Laravel untuk memisahkan mobile dan backend secara rapi
- [x] Breakdown migration Laravel per batch berdasarkan dependensi ERD inti backend
- [x] Panduan eksekusi inisialisasi repo backend Laravel yang siap dijalankan di terminal
- [x] Bootstrap backend Laravel dasar berhasil dijalankan di repo backend terpisah
- [x] Implementasi Batch 1 backend: tabel `roles`, penyesuaian `users`, role seeder, dan admin default seeder berhasil dijalankan
- [x] Implementasi Batch 2 backend: `member_profiles`, `trainer_profiles`, `membership_plans`, dan `member_memberships` berhasil dijalankan
- [x] Auth endpoint dasar backend: `login`, `me`, `logout`, dan alias middleware `role` berhasil diuji end-to-end di repo backend
- [x] Seeder awal backend: `membership_plans` berhasil diisi dengan data paket dasar untuk kebutuhan API publik dan member
- [x] Endpoint publik backend pertama: `GET /api/v1/public/membership-plans` berhasil mengembalikan data paket membership dari database
- [x] Endpoint publik backend kedua: `GET /api/v1/public/trainers` berhasil mengembalikan data trainer dengan format resource yang sesuai kontrak API mobile
- [x] Endpoint publik backend ketiga: `GET /api/v1/public/equipment` berhasil mengembalikan data alat gym dengan format detail yang siap dipakai guest dan member
- [x] Endpoint member backend pertama: `GET /api/v1/member/dashboard` berhasil mengembalikan ringkasan member aktif, membership berjalan, dan sesi berikutnya
- [x] Endpoint member backend kedua: `GET /api/v1/member/profile` berhasil mengembalikan data pribadi, body snapshot dasar, dan membership aktif member
- [x] Endpoint member backend ketiga: `PUT /api/v1/member/profile` berhasil memperbarui data pribadi member dan perubahan langsung tervalidasi lewat endpoint profile
- [x] Endpoint member backend keempat: `GET /api/v1/member/memberships` berhasil mengembalikan membership aktif, histori membership, dan ringkasan status member
- [x] Endpoint member backend kelima: `GET /api/v1/member/transactions` berhasil mengembalikan histori transaksi member lengkap dengan nominal, metode bayar, dan referensi provider
- [x] Endpoint member backend keenam: `POST /api/v1/member/payments/checkout` berhasil membuat transaksi checkout membership `pending` dan langsung muncul di histori transaksi member
- [x] Endpoint member backend ketujuh: `GET /api/v1/member/bookings` berhasil mengembalikan daftar booking PT member lengkap dengan status, jadwal, trainer, dan catatan sesi
- [x] Endpoint member backend kedelapan: `POST /api/v1/member/bookings` berhasil membuat request booking PT baru dan langsung menambahkannya ke daftar booking member
- [x] Endpoint member backend kesembilan: `POST /api/v1/member/bookings/{id}/reschedule` berhasil menjadwalkan ulang booking PT dan perubahan langsung tercermin di daftar booking member
- [x] Validasi rule bisnis booking PT: member tanpa membership aktif terbukti gagal membuat booking dan menerima pesan error yang sesuai
- [x] Endpoint trainer backend pertama: `GET /api/v1/trainer/sessions` berhasil mengembalikan daftar sesi trainer lengkap dengan filter status dan relasi member
- [x] Endpoint trainer backend kedua: `GET /api/v1/trainer/sessions/{id}` berhasil mengembalikan detail sesi trainer yang sesuai untuk flow detail session di mobile
- [x] Endpoint trainer backend ketiga: `POST /api/v1/trainer/sessions/{id}/confirm` berhasil mengonfirmasi booking PT dari sisi trainer dan perubahan status langsung tervalidasi
- [x] Endpoint trainer backend keempat: `GET /api/v1/trainer/dashboard` berhasil mengembalikan ringkasan home trainer lengkap dengan client aktif, sesi hari ini, rating, dan agenda terdekat
- [x] Endpoint trainer backend kelima: `GET /api/v1/trainer/clients` berhasil mengembalikan daftar klien trainer lengkap dengan goal, progress ringkas, sesi berikutnya, dan dukungan query `search`
- [x] Endpoint trainer backend keenam: `GET /api/v1/trainer/clients/{id}` berhasil mengembalikan detail klien trainer lengkap dengan profil member, membership aktif, ringkasan sesi, dan proteksi akses owner trainer
- [x] Endpoint trainer backend ketujuh: `POST /api/v1/trainer/sessions/{id}/reschedule` berhasil menjadwalkan ulang sesi PT dari sisi trainer dan perubahan langsung tervalidasi di detail serta daftar sesi
- [x] Endpoint trainer backend kedelapan: `POST /api/v1/trainer/programs` berhasil membuat draft program trainer untuk klien yang valid dan opsional terkait ke booking sesi
- [x] Endpoint trainer backend kesembilan: `POST /api/v1/trainer/programs/{id}/sessions` berhasil menambahkan sesi ke draft program trainer lengkap dengan urutan, fokus, durasi, dan status awal
- [x] Endpoint trainer backend kesepuluh: `GET /api/v1/trainer/programs/{id}` berhasil mengembalikan detail draft program trainer lengkap dengan header program, relasi klien, booking terkait, daftar sesi, dan summary durasi
- [x] Endpoint trainer backend kesebelas: `PUT /api/v1/trainer/program-sessions/{id}` berhasil memperbarui sesi program trainer dan perubahan langsung tervalidasi di detail program
- [x] Endpoint trainer backend kedua belas: `POST /api/v1/trainer/program-sessions/{id}/exercises` berhasil menambahkan latihan custom ke sesi program trainer lengkap dengan urutan, target otot, set, reps, rest time, dan cue coach
- [x] Endpoint trainer backend ketiga belas: `PUT /api/v1/trainer/program-session-exercises/{id}` berhasil memperbarui latihan pada sesi program trainer dan perubahan langsung tervalidasi di detail program
- [x] Endpoint trainer backend keempat belas: `DELETE /api/v1/trainer/program-session-exercises/{id}` berhasil menghapus latihan dari sesi program trainer dan perubahan langsung tervalidasi di detail program
- [x] Endpoint trainer backend kelima belas: `GET /api/v1/trainer/program-sessions/{id}/progress` berhasil mengembalikan progres sesi trainer lengkap dengan persentase progres, exercise aktif, completed sets, dan status sinkron awal
- [x] Endpoint trainer backend keenam belas: `POST /api/v1/trainer/program-sessions/{id}/progress` berhasil menyinkronkan progres sesi trainer dari sisi PT lengkap dengan completed sets, trainer note, dan perhitungan progress percent
- [x] Endpoint trainer backend ketujuh belas: `POST /api/v1/trainer/program-sessions/{id}/complete` berhasil menutup sesi PT aktif, menaikkan progres ke `100%`, menyelesaikan set tersisa, dan membuka sesi berikutnya
- [x] Sinkronisasi status exercise di detail program setelah sesi trainer diselesaikan sudah rapi, sehingga state progress trainer dan detail program kembali konsisten
- [x] Endpoint member backend berikutnya: `GET /api/v1/member/programs/{id}/tracker` berhasil mengembalikan tracker program read-only dari hasil sinkron trainer lengkap dengan sequence summary, active session, sync label, dan progress percent
- [x] Endpoint member backend berikutnya: `GET /api/v1/member/programs` berhasil mengembalikan daftar program member lengkap dengan progress percent dan active session title
- [x] Endpoint member backend berikutnya: `GET /api/v1/member/programs/{id}` berhasil mengembalikan detail dan ringkasan program member lengkap dengan summary sesi dan exercise count
- [x] Endpoint member backend berikutnya: `POST /api/v1/member/physical-progress` berhasil membuat checkpoint progres fisik member dari backend nyata
- [x] Endpoint member backend berikutnya: `GET /api/v1/member/physical-progress` berhasil mengembalikan latest progress, baseline progress, history, dan summary checkpoint member
- [x] Endpoint member backend berikutnya: `GET /api/v1/member/notifications` berhasil mengembalikan notification center dasar member dari database
- [x] Endpoint member backend berikutnya: `POST /api/v1/member/notifications/{id}/read` berhasil menandai notifikasi member sebagai sudah dibaca
- [x] Fondasi notifikasi FCM-ready: `POST /api/v1/auth/device-token` dan `DELETE /api/v1/auth/device-token` berhasil menyimpan serta menonaktifkan device token per user
- [x] Bootstrap FCM Android di app Flutter: `google-services.json`, `firebase_core`, `firebase_messaging`, plugin Gradle, dan inisialisasi token logging sudah terpasang untuk pengujian device nyata
- [x] Bridge notifikasi database ke FCM push: `POST /api/v1/member/notifications/{id}/push` berhasil mengirim push notification nyata ke device Android yang aktif
- [x] Validasi akhir UI lewat `flutter analyze`
- [x] Validasi widget test dasar
- [x] Guest shell visual pass 1 agar lebih dekat ke referensi ZIP
- [x] Member shell visual pass 1 untuk home, trainer, membership, dan profile
- [x] Trainer shell visual pass 1 untuk home, jadwal, klien, program, dan profile
- [x] Rapikan detail visual pass 1 agar guest, member, dan trainer lebih dekat ke mockup ZIP
- [x] Samakan layout guest, member, dan trainer untuk kebutuhan demo pass 1
- [x] Pixel polish pass 2 untuk komponen umum, guest, member, dan trainer agar hasil demo makin dekat ke Figma/ZIP

### Sedang Dikerjakan

- [ ] Review akhir hasil demo di device HP per screen

### Next Task

- [ ] Sambungkan producer notifikasi otomatis dari event backend ke FCM push dan notification center
- [ ] Setup fondasi admin web dashboard

## Prioritas Paling Dekat

Urutan kerja yang paling masuk akal berikutnya:

1. Pastikan project lolos `format`, `analyze`, dan `test`
2. Review akhir hasil demo utama di device
3. Sambungkan producer notifikasi otomatis dari event backend ke FCM push dan notification center
4. Setup fondasi admin web dashboard

## Command Yang Biasanya Perlu Dijalankan

Jalankan dari root project:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter devices
flutter run -d <device_id>
```

Kalau ada error dari command di atas, kirim output ke saya lalu saya lanjut perbaiki kodenya.

## Catatan Kolaborasi

Aturan kerja supaya cepat:
- saya fokus edit kode dan rapikan task list
- kamu yang jalankan command Flutter kalau perlu
- setelah ada output error, kirim ke saya
- saya lanjut fix sampai aman

## Keputusan Berikutnya

Pilihan lanjut paling masuk akal:

- review hasil pixel polish pass 2 di device HP
- review hasil screen baru dan flow trainer di device HP
- lanjutkan endpoint trainer berikutnya setelah edit sesi program trainer berhasil tervalidasi
- stop dulu dan review hasil yang sudah ada

Kalau task di atas sudah berubah, checklist ini bisa langsung kita update lagi di file ini.
