# Dashboard Penjual - Update Tampilan Pesanan

## 📋 Ringkasan Perubahan

Menambahkan dua status pesanan baru yang terpisah pada dashboard penjual:
- **Sedang Diproses** (untuk pesanan yang sedang dikonfirmasi atau diproses)
- **Sedang Dikirim** (untuk pesanan yang sedang dalam perjalanan)

---

## 🎯 Apa yang Berubah

### Sebelumnya (3 Status)
```
Dashboard Tab Summary:
- Total Pesanan
- Konfirmasi
- Dikirim  
- Selesai

Orders Tab:
[Menunggu Konfirmasi] [Dalam Pengiriman] [Selesai]
```

### Sesudahnya (5 Status)
```
Dashboard Tab Summary:
- Total Pesanan          ✅
- Menunggu Konfirmasi    ✅
- Sedang Diproses        ✨ NEW
- Sedang Dikirim         ✨ NEW
- Selesai                ✅

Orders Tab:
[Menunggu Konfirmasi] [Sedang Diproses] [Selesai]
[Sedang Dikirim]
```

---

## 📝 Detail Implementasi

### File yang Diubah
- `bumdes_frontend/lib/src/screens/store_dashboard_screen.dart`

### Perubahan pada Dashboard Tab (`_buildDashboardTab`)
Penghitungan status diperinci menjadi:
```dart
final waitingConfirmation = _sellerOrders
    .where((order) => order.status == 'Menunggu Pembayaran' || order.status == 'Menunggu Konfirmasi')
    .length;

final processingOrders = _sellerOrders.where((order) => 
  order.status == 'Dikonfirmasi' || order.status == 'Diproses'
).length;

final shippingOrders = _sellerOrders.where((order) => order.status == 'Dikirim').length;

final completedOrders = _sellerOrders.where((order) => order.status == 'Selesai').length;
```

### Perubahan pada Orders Tab (`_buildOrdersTab`)
Layout diubah dari 1 baris 3 kolom menjadi 2 baris:

**Baris 1:** Menunggu Konfirmasi | Sedang Diproses | Selesai
**Baris 2:** Sedang Dikirim (1 kolom, centered)

---

## 🎨 Warna Status

| Status | Warna | Kode |
|--------|-------|------|
| Menunggu Konfirmasi | Orange | `Colors.orange` |
| Sedang Diproses | Yellow | `0xFFFFC107` |
| Sedang Dikirim | Blue | `Colors.blue` |
| Selesai | Green | `Colors.green` |
| Total | Green | `Colors.green` |

---

## 📊 Pemetaan Backend Status

Sistem sekarang mengelompokkan status backend sebagai berikut:

### Menunggu Konfirmasi (Orange)
- `Menunggu Pembayaran`
- `Menunggu Konfirmasi`

### Sedang Diproses (Yellow) ✨ NEW
- `Dikonfirmasi`
- `Diproses`

### Sedang Dikirim (Blue) ✨ NEW
- `Dikirim`

### Selesai (Green)
- `Selesai`

---

## ✅ Testing Checklist

- [ ] Login sebagai Penjual (Seller)
- [ ] Buka Dashboard Tab dan lihat 5 summary cards
- [ ] Buka Pesanan Tab dan lihat 2 baris status cards
- [ ] Verifikasi penghitungan pesanan akurat per status
- [ ] Buat pesanan baru dan ubah statusnya melalui API
- [ ] Verifikasi dashboard update real-time setelah perubahan status
- [ ] Pastikan pesanan muncul di kategori status yang benar

---

## 🔄 User Flow

### Penjual Melihat Dashboard
1. Login sebagai Penjual
2. Lihat 5 summary cards di Dashboard Tab:
   - Total Pesanan
   - Menunggu Konfirmasi
   - Sedang Diproses ← **NEW**
   - Sedang Dikirim ← **NEW**  
   - Selesai

### Penjual Melihat Pesanan Masuk
1. Klik tab "Pesanan"
2. Lihat status pesanan dalam kategori:
   - Menunggu Konfirmasi
   - Sedang Diproses ← **NEW**
   - Selesai
   - Sedang Dikirim ← **NEW**
3. Klik pesanan untuk melihat detail dan ubah status

---

## 🚀 Deployment

File sudah di-format dengan `dart_format` dan tidak memiliki error. Siap untuk:
1. Test pada emulator/device
2. Build APK/IPA
3. Deploy ke production

---

## 📌 Catatan

- Perubahan **backward compatible** - tidak merusak fungsionalitas existing
- API backend sudah mendukung semua status ini
- Penghitungan pesanan otomatis dari data real-time backend
- UI responsif dan scalable untuk jumlah pesanan banyak
