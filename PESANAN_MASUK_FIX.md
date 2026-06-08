# Fix: Pesanan Masuk Blank Screen Issue

## 🐛 Problem
Ketika user mengklik fitur "Pesanan Masuk" dengan status "Sedang Diproses" atau "Sedang Dikirim", layar menampilkan background putih kosong tanpa isi apapun.

## 🔍 Root Cause
Di file `store_dashboard_screen.dart`, method `_buildOrderStatusCard` memiliki mismatch antara nama status yang ditampilkan di dashboard dengan case yang ditangani:

**Dashboard menampilkan:**
- "Menunggu Konfirmasi" ✓
- "Sedang Diproses" ✗
- "Selesai" ✓  
- "Sedang Dikirim" ✗

**Switch statement hanya menangani:**
- "Menunggu Konfirmasi"
- "Dalam Pengiriman" (tidak cocok!)
- "Selesai"

Akibatnya, ketika user klik "Sedang Diproses" atau "Sedang Dikirim", filter menjadi kosong, sehingga SellerOrdersScreen tidak menampilkan order apapun.

## ✅ Fixes Applied

### 1. Fix Switch Statement (store_dashboard_screen.dart)
Diubah case dari `'Dalam Pengiriman'` menjadi `'Sedang Diproses'` dan tambahkan case untuk `'Sedang Dikirim'`:

```dart
// BEFORE (SALAH):
case 'Dalam Pengiriman':
  filters = ['Dikonfirmasi', 'Diproses', 'Dikirim'];
  screenTitle = 'Dalam Pengiriman';
  break;

// AFTER (BENAR):
case 'Sedang Diproses':
  filters = ['Dikonfirmasi', 'Diproses'];
  screenTitle = 'Sedang Diproses';
  break;
case 'Sedang Dikirim':
  filters = ['Dikirim'];
  screenTitle = 'Sedang Dikirim';
  break;
```

### 2. Improve Error Handling (seller_orders_screen.dart)
Tambahkan error handling yang lebih baik:
- ✅ Error message display ketika API gagal
- ✅ Validasi token sebelum API call
- ✅ Empty state UI ketika tidak ada pesanan
- ✅ Retry button untuk reload data

**Improvements:**
```dart
// Sebelum: hanya menampilkan SnackBar (bisa tidak terlihat)
// Sesudah: error message ditampilkan di tengah layar dengan button "Coba Lagi"

// Sebelum: tidak ada validasi token
// Sesudah: check jika token null/empty sebelum call API

// Sebelum: empty list tampil kosong tanpa pesan
// Sesudah: tampil pesan "Belum ada pesanan dengan status ini" dengan icon
```

## 🧪 Testing

Untuk memverifikasi fix:

1. **Buka Flutter app** (jika belum running):
   ```bash
   cd bumdes_frontend
   flutter run -d chrome
   ```

2. **Hot Reload** (jika sudah running):
   - Tekan `r` di terminal atau Ctrl+Shift+;
   
3. **Test setiap status card:**
   - Klik "Menunggu Konfirmasi" → harus tampil order dengan status 'Menunggu Pembayaran' atau 'Menunggu Konfirmasi'
   - Klik "Sedang Diproses" → harus tampil order dengan status 'Dikonfirmasi' atau 'Diproses'
   - Klik "Sedang Dikirim" → harus tampil order dengan status 'Dikirim'
   - Klik "Selesai" → harus tampil order dengan status 'Selesai'

4. **Test error handling:**
   - Jika API error, seharusnya tampil pesan error dengan button "Coba Lagi"
   - Jika tidak ada order, seharusnya tampil pesan "Belum ada pesanan dengan status ini"

## 📋 Files Modified

1. `bumdes_frontend/lib/src/screens/store_dashboard_screen.dart`
   - Line 1613-1630: Fixed switch statement case handling

2. `bumdes_frontend/lib/src/screens/seller_orders_screen.dart`
   - Lines 18-52: Improved error handling and validation
   - Lines 54-90: Better UI for error and empty states

## ⚠️ Notes
- API endpoint `/seller/orders` sudah berjalan dengan baik
- Fix hanya pada frontend (Flutter)
- Kompatibel dengan backend Laravel yang existing
