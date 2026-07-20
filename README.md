# BUMDes Jabar Marketplace

## Profil dan pengenalan aplikasi

BUMDes Jabar adalah platform marketplace digital yang menghubungkan Badan Usaha Milik Desa (BUMDes) di Jawa Barat dengan pembeli, masyarakat, dan mitra usaha secara lebih luas. Aplikasi ini dirancang untuk membantu setiap BUMDes memasarkan produk unggulan, jasa lokal, dan layanan usaha desa secara terorganisir, aman, dan terukur melalui sistem digital.

Tujuan utama aplikasi ini adalah:
- memperluas jangkauan penjualan produk dan jasa BUMDes;
- mempermudah pembeli menemukan produk lokal berkualitas;
- menyediakan sistem transaksi digital yang aman dan transparan;
- memberi dukungan administrasi, pemantauan pesanan, dan pelaporan bagi pengelola platform.

## Siapa yang memakai aplikasi ini?

Aplikasi ini mendukung tiga peran utama:
- Pembeli: mencari produk/jasa, menambahkan ke keranjang, melakukan checkout, dan melihat riwayat pesanan.
- Penjual / BUMDes: mengelola toko, katalog produk, stok, status pesanan, dan saldo pendapatan.
- Admin: mengelola pengguna, toko, produk, pesanan, peninjauan usaha, dan dashboard platform.

## Fitur utama

### 1. Manajemen pengguna dan akun
- registrasi dan login pengguna;
- profil pengguna yang bisa diperbarui;
- pengelolaan foto profil dan data toko;
- autentikasi berbasis token untuk keamanan API.

### 2. Katalog produk dan jasa
- daftar produk/jasa berdasarkan kategori;
- pencarian produk berdasarkan kata kunci;
- filter kategori, harga, dan status;
- halaman detail produk beserta deskripsi dan foto.

### 3. Toko BUMDes
- setiap toko BUMDes dapat mengelola profil dan informasi usaha;
- penjual bisa mengunggah produk, mengatur stok, dan mengelola penjualan;
- toko dapat menampilkan identitas desa, lokasi, dan informasi kontak.

### 4. Keranjang dan transaksi
- pembeli dapat menambahkan produk ke keranjang;
- proses checkout dan pemesanan yang terstruktur;
- integrasi pembayaran digital melalui Midtrans dan Xendit;
- upload bukti pembayaran dan konfirmasi pembayaran.

### 5. Pengelolaan pesanan
- pembeli bisa melihat status pesanan dari dibuat sampai selesai;
- penjual bisa mengubah status pesanan dan menindaklanjuti pengiriman;
- pengguna bisa mengonfirmasi penerimaan barang atau membatalkan pesanan sesuai aturan aplikasi.

### 6. Saldo, wallet, dan laporan
- fitur wallet untuk penjual;
- riwayat transaksi dan penarikan saldo;
- dashboard laporan pembeli, toko, dan platform untuk admin.

### 7. Notifikasi dan integrasi otomatis
- integrasi notifikasi otomatis melalui n8n dan Telegram;
- webhook pembayaran dan pemberitahuan status pesanan untuk mendukung proses bisnis lebih cepat.

## Tampilan dan alur aplikasi

Aplikasi ini terdiri dari dua sisi utama:
- Frontend: aplikasi Flutter untuk tampilan web dan mobile;
- Backend: API Laravel untuk autentikasi, data, transaksi, pembayaran, dan admin.

### Alur pengguna yang umum
1. Pengguna mendaftar dan login.
2. Pembeli melihat katalog produk/jasa di halaman utama.
3. Pembeli memilih produk, memasukkan ke keranjang, dan melakukan checkout.
4. Sistem memproses pembayaran dan menyimpan bukti transaksi.
5. Penjual menerima pesanan, mengubah status, dan mengirimkan produk/jasa.
6. Admin memantau aktivitas platform dan mengelola data pengguna serta toko.

## Struktur proyek

- Frontend: [bumdes_frontend](bumdes_frontend)
- Backend/API: [bumdes_jabar/laravel](bumdes_jabar/laravel)
- Docker Compose: [docker-compose.yml](docker-compose.yml)
- Workflow otomatis: [n8n](n8n)

## Infrastruktur dan arsitektur

Aplikasi ini dibangun dengan arsitektur modular:
- Frontend Flutter untuk antarmuka pengguna.
- Backend Laravel untuk business logic, API REST, autentikasi, dan integrasi payment.
- Database MySQL untuk penyimpanan data transaksi, pengguna, produk, toko, dan pesanan.
- Docker Compose untuk menjalankan backend, frontend, database, dan n8n dalam satu ekosistem.
- Storage publik untuk file foto produk, profil, toko, dan bukti pembayaran.

### Komponen utama
- Frontend web/mobile: Flutter
- Backend API: Laravel 10
- Database: MySQL 8
- Auth: Laravel Sanctum
- Payment gateway: Midtrans, Xendit
- File storage: Laravel public disk dengan proxy gambar
- Automation notification: n8n + Telegram

## Cara penggunaan

### Untuk pembeli
1. Daftar akun atau login.
2. Jelajahi produk/jasa dari berbagai BUMDes.
3. Pilih produk yang diinginkan.
4. Masukkan ke keranjang dan lanjutkan checkout.
5. Lakukan pembayaran melalui gateway yang tersedia.
6. Pantau status pesanan dari riwayat transaksi.

### Untuk penjual / BUMDes
1. Login ke akun penjual.
2. Lengkapi profil toko dan data usaha.
3. Tambahkan produk atau jasa beserta detail dan foto.
4. Pantau pesanan yang masuk.
5. Update status pesanan dan kelola pembayaran serta saldo.

### Untuk admin
1. Login sebagai admin.
2. Kelola pengguna, toko, produk, dan pesanan.
3. Tinjau produk yang memerlukan persetujuan.
4. Pantau statistik platform dan aktivitas transaksi.

## Instalasi teknis

### Prasyarat
- PHP 8.1+
- Composer
- MySQL 8.0+
- Flutter SDK 3.11+
- Docker Desktop dan Docker Compose (opsional, tetapi disarankan)
- Git

### 1. Menjalankan backend secara lokal

```bash
cd bumdes_jabar/laravel
composer install
cp .env.example .env
php artisan key:generate
```

Setel konfigurasi database di file `.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bumdes_jabar
DB_USERNAME=root
DB_PASSWORD=
FILESYSTEM_DISK=public
```

Buat database MySQL terlebih dahulu:

```bash
mysql -u root -e "CREATE DATABASE bumdes_jabar;"
```

Jalankan migrasi dan seed data:

```bash
php artisan migrate
php artisan db:seed
php artisan storage:link
php artisan serve
```

Backend akan tersedia di:
- http://127.0.0.1:8000

### 2. Menjalankan frontend secara lokal

```bash
cd bumdes_frontend
flutter pub get
flutter run -d chrome
```

Untuk perangkat mobile/emulator, gunakan perintah yang sesuai dengan target device Anda.

### 3. Menjalankan semua layanan dengan Docker Compose

Di direktori root proyek:

```bash
docker compose up --build
```

Layanan yang tersedia:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- Database MySQL: localhost:3306
- n8n: http://localhost:5678

Untuk menghentikan layanan:

```bash
docker compose down
```

Untuk membersihkan volume database:

```bash
docker compose down -v
```

## Variabel lingkungan penting

### Backend
Contoh variabel yang biasanya perlu disesuaikan:

```env
APP_NAME=BUMDes Jabar
APP_ENV=local
APP_DEBUG=true
APP_URL=http://127.0.0.1:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bumdes_jabar
DB_USERNAME=root
DB_PASSWORD=
FILESYSTEM_DISK=public
```

### Frontend
Jika Anda menjalankan frontend dengan backend yang berbeda dari default, gunakan variabel build atau define:

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000
```

## Troubleshooting umum

- Pastikan MySQL sudah berjalan dan database sudah dibuat.
- Jalankan `php artisan storage:link` jika gambar tidak muncul.
- Jika frontend tidak bisa terhubung ke backend, pastikan URL API benar dan backend sedang berjalan.
- Jika ada masalah CORS pada gambar, cek route proxy image yang ada di backend.
- Jika Anda menjalankan di Docker, pastikan port 3000, 8000, 3306, dan 5678 tidak sedang dipakai aplikasi lain.

## Dokumentasi tambahan

Untuk detail yang lebih spesifik, lihat dokumen pendukung berikut:
- [bumdes_jabar/laravel/README.md](bumdes_jabar/laravel/README.md)
- [bumdes_frontend/README.md](bumdes_frontend/README.md)
- [ARCHITECTURE_FLOW_DIAGRAM.md](ARCHITECTURE_FLOW_DIAGRAM.md)
- [QUICK_START.md](QUICK_START.md)

## Status proyek

- Status: In Development
- Versi dokumentasi: 1.2
- Terakhir diperbarui: 20 Juli 2026
