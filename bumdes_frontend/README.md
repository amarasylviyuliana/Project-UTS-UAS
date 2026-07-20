# BUMDes Jabar Frontend

## Profil aplikasi

Frontend ini merupakan antarmuka pengguna dari platform BUMDes Jabar yang dirancang untuk memudahkan pembeli, penjual BUMDes, dan admin berinteraksi dengan sistem marketplace secara digital. Aplikasi ini dikembangkan dengan Flutter sehingga dapat berjalan di web dan perangkat mobile dengan pengalaman antarmuka yang konsisten.

Tujuan utama frontend ini adalah menyediakan tampilan yang intuitif untuk:
- menjelajahi produk dan jasa BUMDes;
- melakukan pencarian dan filtering data;
- mengelola keranjang belanja dan checkout;
- melihat status pesanan;
- mengakses profil toko, profil pengguna, dan dashboard admin.

## Fitur utama frontend

- Halaman beranda dengan katalog produk dan toko BUMDes
- Halaman detail produk dan detail toko
- Fitur pencarian dan kategori produk
- Keranjang belanja dan alur checkout
- Halaman riwayat pesanan dan status pesanan
- Profil pengguna, profil toko, dan fitur upload foto
- Integrasi pembayaran Midtrans
- Dashboard admin untuk mengelola pengguna, toko, produk, dan order
- Integrasi gambar melalui proxy API untuk menghindari masalah CORS

## Tampilan dan pengalaman pengguna

Aplikasi frontend dibuat dengan pendekatan user-friendly dan responsif, sehingga pengguna dapat:
- melihat produk dengan cepat;
- melakukan navigasi antar halaman tanpa hambatan;
- mengakses fitur transaksi secara langsung;
- memantau proses pembelian dan pembayaran dengan lebih mudah.

Secara umum, alur pengguna frontend adalah:
1. pengguna membuka aplikasi;
2. memilih produk atau toko;
3. menambahkan item ke keranjang;
4. melakukan checkout;
5. melihat status pembayaran dan pesanan;
6. mengakses profil atau dashboard sesuai peran.

## Struktur frontend

Berikut struktur utama pada proyek frontend:

```text
lib/
├── main.dart
├── src/
│   ├── config/
│   ├── models/
│   ├── services/
│   ├── screens/
│   └── widgets/
```

## Teknologi yang digunakan

- Flutter SDK 3.11+
- Dart
- Provider untuk state management
- HTTP untuk komunikasi API
- Flutter Secure Storage untuk penyimpanan token
- Image Picker untuk unggah foto
- WebView dan URL Launcher untuk pembayaran dan tautan eksternal
- Midtrans SDK untuk integrasi pembayaran

## Cara penggunaan aplikasi

### Untuk pembeli
1. Buka aplikasi dan login/register.
2. Jelajahi katalog produk atau jasa dari berbagai BUMDes.
3. Pilih produk dan lanjutkan ke keranjang.
4. Lakukan checkout dan pembayaran.
5. Pantau status pesanan melalui menu riwayat.

### Untuk penjual / BUMDes
1. Login ke akun penjual.
2. Lengkapi profil toko.
3. Kelola produk, stok, dan pesanan.
4. Pantau transaksi dan saldo dari dashboard penjual.

### Untuk admin
1. Login sebagai admin.
2. Akses dashboard untuk mengelola pengguna, toko, produk, dan order.
3. Lakukan monitoring dan pengaturan platform.

## Instalasi teknis

### Prasyarat
- Flutter SDK 3.11+
- Dart SDK sesuai versi Flutter
- Android Studio / VS Code dengan extension Flutter
- Koneksi ke backend API yang sedang berjalan

### Langkah instalasi

1. Masuk ke folder frontend

```bash
cd bumdes_frontend
```

2. Install dependensi

```bash
flutter pub get
```

3. Jalankan aplikasi

Untuk web:

```bash
flutter run -d chrome
```

Untuk Android emulator:

```bash
flutter run
```

### Konfigurasi backend URL

Frontend ini terhubung ke backend melalui konfigurasi API. Secara default, aplikasi akan menggunakan:

- development: http://127.0.0.1:8000
- production: https://bumdes-api-production.up.railway.app

Jika Anda ingin mengubah URL backend secara manual, jalankan:

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000
```

## Integrasi pembayaran Midtrans

Saat pengguna melakukan checkout, frontend akan memanggil endpoint backend untuk mendapatkan token pembayaran. Jika token tersedia, aplikasi akan membuka layar pembayaran Midtrans secara otomatis.

Catatan penting:
- backend harus berjalan dan terhubung ke konfigurasi Midtrans yang valid;
- untuk testing webhook lokal, gunakan alat seperti ngrok;
- pastikan variabel environment backend sudah diset dengan benar.

## Troubleshooting umum

- Jika aplikasi tidak bisa terhubung ke backend, cek URL API dan pastikan backend sedang berjalan.
- Jika gambar tidak tampil, pastikan backend mengembalikan file melalui route proxy image.
- Jika ada error saat menjalankan Flutter, pastikan SDK Flutter sudah terinstall dan environment PATH sudah benar.
- Jika menjalankan di browser, pastikan port backend tidak diblokir dan CORS sudah diatur dengan baik.

## Dokumentasi terkait

- [../README.md](../README.md)
- [../bumdes_jabar/laravel/README.md](../bumdes_jabar/laravel/README.md)
- [../QUICK_START.md](../QUICK_START.md)
