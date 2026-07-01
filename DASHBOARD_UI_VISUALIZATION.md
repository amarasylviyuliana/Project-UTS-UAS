# Dashboard Penjual - Visualisasi Perubahan UI

## 📱 Dashboard Tab - Sebelum & Sesudah

### ❌ SEBELUMNYA (3 Summary Cards)
```
┌─────────────────────────────────┐
│     Halo Penjual               │  ← "Lihat Pesanan" Button
│  Lihat ringkasan toko...       │
└─────────────────────────────────┘

┌──────────┬──────────┬──────────┬──────────┐
│ Total    │ Konfir-  │ Dikirim  │ Selesai  │
│ Pesanan  │ masi     │          │          │
│ 15       │ 3        │ 2        │ 8        │
└──────────┴──────────┴──────────┴──────────┘
```

### ✅ SESUDAHNYA (5 Summary Cards)
```
┌─────────────────────────────────┐
│     Halo Penjual               │  ← "Lihat Pesanan" Button
│  Lihat ringkasan toko...       │
└─────────────────────────────────┘

┌──────────┬──────────┬──────────┬──────────┬──────────┐
│ Total    │ Menunggu │ Sedang   │ Sedang   │ Selesai  │
│ Pesanan  │Konfirmasi│Diproses  │ Dikirim  │          │
│ 15       │ 3        │ 2        │ 4        │ 8        │
└──────────┴──────────┴──────────┴──────────┴──────────┘
```

---

## 📋 Orders Tab - Sebelum & Sesudah

### ❌ SEBELUMNYA (1 Baris, 3 Kolom)
```
═══════════════════════════════════════════════════

PESANAN MASUK

┌─────────────────┬──────────────────┬──────────────────┐
│ Menunggu        │ Dalam Pengiriman │ Selesai          │
│ Konfirmasi      │                  │                  │
│ 3 Pesanan       │ 6 Pesanan        │ 8 Pesanan        │
│ 🟠 Orange       │ 🔵 Blue          │ 🟢 Green         │
└─────────────────┴──────────────────┴──────────────────┘

═══════════════════════════════════════════════════
DAFTAR PESANAN

[Order List...]
```

### ✅ SESUDAHNYA (2 Baris, 4 Kolom)
```
═══════════════════════════════════════════════════

PESANAN MASUK

BARIS 1:
┌──────────────────┬──────────────────┬──────────────────┐
│ Menunggu         │ Sedang Diproses  │ Selesai          │
│ Konfirmasi       │                  │                  │
│ 3 Pesanan        │ 2 Pesanan        │ 8 Pesanan        │
│ 🟠 Orange        │ 🟡 Yellow        │ 🟢 Green         │
└──────────────────┴──────────────────┴──────────────────┘

BARIS 2:
┌──────────────────┬──────────────────┬──────────────────┐
│ Sedang Dikirim   │                  │                  │
│ 4 Pesanan        │ [Empty]          │ [Empty]          │
│ 🔵 Blue          │                  │                  │
└──────────────────┴──────────────────┴──────────────────┘

═══════════════════════════════════════════════════
DAFTAR PESANAN

[Order List...]
```

---

## 🎨 Warna & Arti Status

```
🟠 ORANGE - Menunggu Konfirmasi
   └─ Status: Menunggu Pembayaran, Menunggu Konfirmasi
   └─ Aksi: Penjual belum mengkonfirmasi pesanan
   └─ Penjual perlu: Melihat detail dan konfirmasi/tolak

🟡 YELLOW - Sedang Diproses ✨ NEW
   └─ Status: Dikonfirmasi, Diproses
   └─ Aksi: Penjual sedang menyiapkan/memproses pesanan
   └─ Penjual perlu: Menyiapkan barang untuk dikirim

🔵 BLUE - Sedang Dikirim ✨ NEW
   └─ Status: Dikirim
   └─ Aksi: Pesanan dalam perjalanan ke pembeli
   └─ Penjual perlu: Melacak pengiriman

🟢 GREEN - Selesai
   └─ Status: Selesai
   └─ Aksi: Pesanan sudah diterima pembeli
   └─ Penjual perlu: Arsip/lihat histori
```

---

## 📊 Contoh Data Real

```
Total 15 Pesanan

Status Breakdown:
├─ Menunggu Pembayaran      : 1 pesanan
├─ Menunggu Konfirmasi      : 2 pesanan
│  └─ [Menunggu Konfirmasi] : 3 pesanan  🟠
├─ Dikonfirmasi             : 1 pesanan
├─ Diproses                 : 1 pesanan
│  └─ [Sedang Diproses]     : 2 pesanan  🟡
├─ Dikirim                  : 4 pesanan
│  └─ [Sedang Dikirim]      : 4 pesanan  🔵
└─ Selesai                  : 8 pesanan
   └─ [Selesai]             : 8 pesanan  🟢
```

---

## 🔄 Interaksi Pengguna

### Penjual Masuk ke Dashboard
```
1. Login → 2. Dashboard Tab → Lihat 5 summary cards
```

### Penjual Melihat Pesanan Detail
```
1. Login → 2. Click "Lihat Pesanan" atau tab "Pesanan"
          → 3. Lihat 2 baris status cards
          → 4. Filter/cari pesanan
          → 5. Klik pesanan → Lihat detail & ubah status
```

### Penjual Update Status Pesanan
```
1. Pesanan masuk (status: Menunggu Konfirmasi)
2. Penjual klik pesanan → Lihat detail
3. Penjual ubah status → Dikonfirmasi (pindah ke Sedang Diproses)
4. Dashboard update otomatis
5. Penjual siap kirimen → Ubah status → Dikirim
6. Pesanan pindah ke Sedang Dikirim
7. Pembeli terima → Status → Selesai
```

---

## 💾 Data Flow

```
Backend (Laravel) ←→ Frontend (Flutter)

GET /api/seller/orders
│
└─→ Return [
    { id: 1, status: "Dikonfirmasi", ... },
    { id: 2, status: "Diproses", ... },
    { id: 3, status: "Dikirim", ... },
    ...
  ]

Frontend Group by Status:
├─ Menunggu Konfirmasi: 3
├─ Dikonfirmasi: 1  ┐
├─ Diproses: 1      ├─ Sedang Diproses: 2
├─ Dikirim: 4       
├─ Selesai: 8

Display di Dashboard:
┌─────────┬──────────┬─────────┬──────────┬────────┐
│ Total   │ Menunggu │ Sedang  │ Sedang   │ Selesai│
│ 15      │ 3        │ 2       │ 4        │ 8      │
└─────────┴──────────┴─────────┴──────────┴────────┘
```

---

## ✨ Keuntungan Perubahan Ini

✅ **Lebih Jelas**: Penjual bisa membedakan status pesanan dengan jelas
✅ **Lebih Detail**: 5 kategori vs 3 sebelumnya
✅ **Better UX**: Layout 2 baris lebih mudah dibaca
✅ **Real-time**: Update otomatis dari backend
✅ **Actionable**: Penjual tahu apa yang harus dilakukan untuk setiap status
