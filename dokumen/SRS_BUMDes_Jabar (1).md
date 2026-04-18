# Software Requirements Specification (SRS)
## BUMDes Jabar  
Marketplace Produk & Jasa Antar BUMDes di Jawa Barat

**Versi Dokumen:** 1.0 (Approved)  
**Status:** Draft  
**Disusun oleh:** Kelompok 5 - Tim Pengembang BUMDes Jabar  

1. Abdillah Syafiq Gaos  
2. Aril Zulfikar  
3. Amara Sylvi Yuliana  
4. Hilman  
5. Mochammad Adhi R  
6. Sheva Heizatul I  
7. Yunita Nur ‘Aini  

**Organisasi:** Prodi Sistem Informasi - Kelas A2 - Universitas Kebangsaan Republik Indonesia  
**Tanggal:** April 2026

---

## Riwayat Revisi

| Nama | Tanggal | Alasan Perubahan | Versi |
|------|--------|----------------|------|
| Tim Pengembang | April 2026 | Pembuatan dokumen awal | 1.0 |

---

## Daftar Isi
1. Pendahuluan  
2. Deskripsi Umum  
3. Kebutuhan Antarmuka Eksternal  
4. Fitur Sistem  
5. Kebutuhan Non-Fungsional  
6. Kebutuhan Lainnya  
Lampiran A, B, C  

---

# 1. Pendahuluan

## 1.1 Tujuan
Dokumen ini mendefinisikan kebutuhan sistem **BUMDes Jabar**, platform marketplace berbasis web & mobile untuk menghubungkan BUMDes di Jawa Barat.

## 1.2 Konvensi Dokumen
- Kode kebutuhan: `REQ-XX`
- Istilah teknis: *italic*
- Field/kode: `monospace`
- Prioritas: Tinggi, Sedang, Rendah

## 1.3 Audiens

| Stakeholder | Peran | Bagian |
|------------|------|--------|
| Mahasiswa | Pengembang | Semua |
| Dosen | Evaluasi | Bab 1,2,4,5 |
| Pengelola BUMDes | Pengguna | Bab 2 & 4 |

## 1.4 Ruang Lingkup
Platform digital untuk:
- Jual beli produk & jasa desa
- Digitalisasi ekonomi desa
- Memperluas pasar

## 1.5 Referensi
- IEEE 830-1998
- Karl Wiegers SRS
- Laravel Docs
- Flutter Docs

---

# 2. Deskripsi Umum

## 2.1 Perspektif Produk
Sistem terdiri dari:
- Mobile App (Flutter)
- Backend API (Laravel)
- Database (MySQL)

## 2.2 Fungsi Produk
1. Registrasi & Login  
2. Manajemen Profil  
3. Kelola Produk  
4. Pencarian  
5. Keranjang  
6. Pembayaran  
7. Laporan  

## 2.3 Kelas Pengguna

| Pengguna | Karakteristik | Hak Akses |
|---------|--------------|----------|
| Pembeli | Umum | Beli produk |
| Penjual | BUMDes | Kelola toko |
| Admin | Sistem | Full akses |
| Tamu | Guest | Lihat saja |

## 2.4 Lingkungan Operasional
- Android ≥ 8.0  
- iOS ≥ 13  
- Server Linux + Docker  
- MySQL 8  

## 2.5 Batasan
- Tanpa OTP  
- Tanpa payment gateway  
- Transfer manual  
- Fokus Jawa Barat  

---

# 3. Kebutuhan Antarmuka

## 3.1 UI
- Flutter + Material Design
- Navigasi sederhana
- Bahasa Indonesia

## 3.2 Hardware
- RAM ≥ 2GB (mobile)
- Server minimal 4GB RAM

## 3.3 Software
- MySQL
- SMTP
- JWT Auth

## 3.4 Komunikasi
- HTTPS
- JSON API
- Bearer Token

---

# 4. Fitur Sistem

## 4.1 Registrasi & Login

### Kebutuhan
| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-01 | Form daftar | Tinggi |
| REQ-02 | Validasi email/password | Tinggi |
| REQ-03 | Email konfirmasi | Tinggi |
| REQ-04 | JWT Token | Tinggi |
| REQ-05 | Error handling | Tinggi |
| REQ-06 | Logout | Sedang |

---

## 4.2 Manajemen Profil

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-07 | Lihat profil | Sedang |
| REQ-08 | Edit profil | Sedang |
| REQ-09 | Profil toko | Tinggi |
| REQ-10 | Ganti password | Sedang |

---

## 4.3 Produk & Jasa

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-11 | Tambah produk | Tinggi |
| REQ-12 | Edit produk | Tinggi |
| REQ-13 | Hapus produk | Tinggi |
| REQ-14 | Status stok | Sedang |
| REQ-15 | Moderasi admin | Sedang |

---

## 4.4 Pencarian

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-16 | Search real-time | Tinggi |
| REQ-17 | Kategori | Tinggi |
| REQ-18 | Detail produk | Tinggi |
| REQ-19 | Filter | Sedang |
| REQ-20 | Produk unggulan | Sedang |

---

## 4.5 Keranjang

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-21 | Kelola keranjang | Tinggi |
| REQ-22 | Buat pesanan | Tinggi |
| REQ-23 | Status awal | Tinggi |
| REQ-24 | Update status | Tinggi |
| REQ-25 | Konfirmasi | Sedang |

---

## 4.6 Pembayaran

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-26 | Info rekening | Tinggi |
| REQ-27 | Upload bukti | Tinggi |
| REQ-28 | Simpan bukti | Tinggi |
| REQ-29 | Verifikasi | Tinggi |
| REQ-30 | Penolakan | Sedang |

---

## 4.7 Laporan

| Kode | Deskripsi | Prioritas |
|------|----------|----------|
| REQ-31 | Riwayat | Sedang |
| REQ-32 | Laporan toko | Sedang |
| REQ-33 | Laporan admin | Sedang |
| REQ-34 | Review | Rendah |

---

# 5. Non-Fungsional

## 5.1 Performa
- Load < 3 detik  
- API < 2 detik  
- 100 user aktif  

## 5.2 Safety
- Backup harian  
- Atomic transaction  

## 5.3 Security
- HTTPS  
- Bcrypt  
- JWT  
- Rate limiting  

## 5.4 Quality
- Usability tinggi  
- Availability 99%  
- Maintainable  

## 5.5 Aturan Bisnis
- 1 akun = 1 toko  
- Review setelah selesai  
- Admin bisa suspend  

---

# Lampiran A - Glosarium
- BUMDes: Badan Usaha Milik Desa  
- API: komunikasi aplikasi  
- JWT: token autentikasi  
- REST: arsitektur API  

---

# Lampiran B - Model
- Use Case  
- ERD  
- Sequence  
- Deployment  

---

# Lampiran C - TBD

| No | Item | Keterangan |
|----|------|-----------|
| 1 | Rekening | Input penjual |
| 2 | ToS | Belum ada |
| 3 | Batas produk | TBD |
| 4 | Dispute | TBD |
| 5 | Notifikasi | Opsional |

---

**— END OF DOCUMENT —**
