# Troubleshooting Checkout Feature

## Fixed Issues (May 19, 2026)

### 1. ✅ Authentication Guard Configuration
**Problem**: Routes menggunakan `auth:sanctum` tapi guard tidak dikonfigurasi
**Solution**: 
- Added 'api' guard dengan 'sanctum' driver di `config/auth.php`
- Added sanctum middleware alias di `app/Http/Kernel.php`

### 2. ✅ Order Validation Enhancement
**Improvements**:
- Better error messages dengan error codes
- Validasi semua produk aktif sebelum checkout
- Cek stok produk tersedia
- Validasi total pesanan > 0

---

## Checklist Frontend

Sebelum checkout berfungsi, pastikan:

### Authentication Check
- [ ] User sudah login dan mendapat `token` dari endpoint `/api/auth/login`
- [ ] Token dikirim di header: `Authorization: Bearer {token}`
- [ ] Token masih valid (belum expired)

### Cart Check
- [ ] Keranjang tidak kosong: `GET /api/cart` return items
- [ ] Semua item dari toko yang sama
- [ ] Stok masih cukup untuk setiap item

### Checkout Request Format

**Method**: `POST /api/orders`

**Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Body**:
```json
{
    "recipient_name": "Nama Penerima",
    "delivery_address": "Jl. Contoh No. 123, Kota, Provinsi 12345",
    "notes": "Catatan untuk penjual (opsional)"
}
```

### Expected Success Response (201)
```json
{
    "message": "Pesanan berhasil dibuat",
    "code": "ORDER_CREATED",
    "data": {
        "id": 1,
        "order_number": "ORD-20260519143045-ABC123",
        "buyer_id": 1,
        "store_id": 1,
        "status": "Menunggu Pembayaran",
        "recipient_name": "Nama Penerima",
        "delivery_address": "Jl. Contoh No. 123",
        "notes": null,
        "total_price": "300000.00",
        "created_at": "2026-05-19T14:30:45.000000Z",
        "orderItems": [...],
        "store": {...},
        "payment": {
            "id": 1,
            "order_id": 1,
            "status": "Pending",
            "created_at": "2026-05-19T14:30:45.000000Z"
        }
    }
}
```

---

## Error Responses & Solutions

### 401 - User Not Authenticated
```json
{
    "message": "User tidak terautentikasi",
    "code": "UNAUTHENTICATED"
}
```
**Solution**: 
- Pastikan token ada di header `Authorization: Bearer {token}`
- Pastikan token masih valid
- Re-login jika token expired

### 422 - Empty Cart
```json
{
    "message": "Keranjang kosong. Silakan tambahkan produk terlebih dahulu.",
    "code": "EMPTY_CART"
}
```
**Solution**: Tambah produk ke keranjang terlebih dahulu

### 422 - Product Not Found
```json
{
    "message": "Produk dalam keranjang tidak ditemukan",
    "code": "PRODUCT_NOT_FOUND"
}
```
**Solution**: 
- Produk mungkin sudah dihapus
- Clear cart dan tambah produk baru

### 422 - Product Inactive
```json
{
    "message": "Produk 'Nama Produk' tidak lagi tersedia",
    "code": "PRODUCT_INACTIVE"
}
```
**Solution**: Produk sudah dinonaktifkan penjual, ganti dengan produk lain

### 422 - Insufficient Stock
```json
{
    "message": "Stok produk 'Nama Produk' tidak cukup. Stok tersedia: 5",
    "code": "INSUFFICIENT_STOCK"
}
```
**Solution**: Kurangi jumlah item atau pilih produk lain

### 422 - Multiple Stores
```json
{
    "message": "Anda hanya dapat memesan dari satu toko sekaligus. Keranjang Anda berisi produk dari 2 toko berbeda.",
    "code": "MULTIPLE_STORES"
}
```
**Solution**: Hapus item dari salah satu toko, atau checkout secara terpisah

---

## Debug Steps

### 1. Verify Database Connection
```bash
cd c:\laragon\www\bumdes_jabar\laravel
php artisan migrate:status
```

### 2. Test Login Token
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 3. Verify Token Works
```bash
curl -X GET http://localhost:8000/api/auth/me \
  -H "Authorization: Bearer {your_token}"
```

### 4. Check Cart Items
```bash
curl -X GET http://localhost:8000/api/cart \
  -H "Authorization: Bearer {your_token}"
```

### 5. Test Checkout
```bash
curl -X POST http://localhost:8000/api/orders \
  -H "Authorization: Bearer {your_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient_name": "Test User",
    "delivery_address": "Jl. Test 123",
    "notes": "Test order"
  }'
```

### 6. Check Laravel Logs
```bash
cat storage/logs/laravel.log
```

---

## Configuration Checklist

- [x] `config/auth.php` - API guard dengan sanctum driver
- [x] `app/Http/Kernel.php` - Sanctum middleware registered
- [x] `.env` - DB_CONNECTION=mysql dan database credentials valid
- [x] Database migrations sudah dijalankan
- [x] User sudah terdaftar dan verified
- [x] Token generation working di login
- [x] Cart items tersimpan dengan benar

---

## Next Steps

1. **Clear Laravel Cache** (jika masih error setelah fix):
```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
```

2. **Test dari Frontend** dengan error handling lengkap
3. **Monitor Logs** di `storage/logs/laravel.log` untuk errors
4. **Validate Response** sesuai dengan format yang didokumentasikan
