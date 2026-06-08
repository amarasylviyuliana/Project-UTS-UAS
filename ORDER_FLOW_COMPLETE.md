# 🔄 Complete Order Flow - BUMDes Marketplace

## Overview
Alur pesanan yang lengkap dari pembeli, ke penjual, hingga selesai dan terekam di admin dengan semua status tracking yang akurat.

---

## 📋 Daftar Status Pesanan

| No | Status | Aktor | Deskripsi |
|----|----|----|----|
| 1 | **Menunggu Pembayaran** | Pembeli | Order baru dibuat, menunggu pembeli melakukan pembayaran |
| 2 | **Menunggu Konfirmasi** | Penjual | Bukti pembayaran sudah diterima, menunggu penjual konfirmasi |
| 3 | **Dikonfirmasi** | Penjual | Penjual sudah konfirmasi pembayaran, order sah |
| 4 | **Diproses** | Penjual | Penjual sedang mempersiapkan barang untuk dikirim |
| 5 | **Dikirim** | Penjual | Barang sudah dikirim ke pembeli |
| 6 | **Selesai** | Pembeli | Pembeli konfirmasi penerimaan barang, order selesai |
| 7 | **Dibatalkan** | Pembeli/Penjual | Order dibatalkan (hanya jika belum dibayar) |

---

## 🔄 STATE TRANSITION DIAGRAM

```
START
  ↓
┌─────────────────────────────────────────┐
│ 1. MENUNGGU PEMBAYARAN                  │
│ - Pembeli baru saja checkout             │
│ - Status: Waiting for payment            │
└─────────────────────────────────────────┘
  ↓ (Pembeli upload bukti pembayaran)
┌─────────────────────────────────────────┐
│ 2. MENUNGGU KONFIRMASI                  │
│ - Bukti pembayaran sudah di-upload      │
│ - Menunggu penjual konfirmasi            │
└─────────────────────────────────────────┘
  ↓ (Penjual konfirmasi pembayaran)
┌─────────────────────────────────────────┐
│ 3. DIKONFIRMASI                         │
│ - Penjual sudah konfirmasi pembayaran   │
│ - Order siap diproses                   │
└─────────────────────────────────────────┘
  ↓ (Penjual update status)
┌─────────────────────────────────────────┐
│ 4. DIPROSES                             │
│ - Penjual sedang mempersiapkan barang   │
│ - Barang siap untuk dikirim             │
└─────────────────────────────────────────┘
  ↓ (Penjual update status)
┌─────────────────────────────────────────┐
│ 5. DIKIRIM                              │
│ - Barang sudah dikirim                  │
│ - Menunggu pembeli konfirmasi penerimaan│
│ - delivered_at timestamp recorded        │
└─────────────────────────────────────────┘
  ↓ (Pembeli konfirmasi penerimaan)
┌─────────────────────────────────────────┐
│ 6. SELESAI ✓                            │
│ - Order selesai                          │
│ - completed_at timestamp recorded        │
│ - Bisa di-review                        │
└─────────────────────────────────────────┘

ALTERNATIF:
- Pembeli bisa BATALKAN order saat status Menunggu Pembayaran
- Penjual bisa REJECT pembayaran jika bukti tidak sesuai
```

---

## 📱 BUYER SIDE FLOW

### 1️⃣ Phase 1: Browsing & Cart
```
[Home Page]
    ↓
[Select Products]
    ↓
[Add to Cart]
    ↓
[View Cart]
    ↓
[Proceed to Checkout]
```

**Endpoints:**
- `GET /api/products` - List produk
- `POST /api/cart/add` - Tambah ke cart
- `GET /api/cart` - View cart
- `POST /api/cart/clear` - Clear cart

---

### 2️⃣ Phase 2: Checkout & Order Creation
```
[Checkout Form]
  ├─ Recipient Name (wajib)
  ├─ Recipient Phone (opsional)
  ├─ Recipient Address (wajib)
  ├─ Notes (opsional)
  └─ [Submit Checkout]
        ↓
[Order Created]
  ├─ Order ID: 1
  ├─ Order Number: ORD-20260608143022-ABC123
  ├─ Status: Menunggu Pembayaran
  ├─ Total: Rp 100.000
  └─ Payment: Pending
        ↓
[Redirect to Payment Gateway]
```

**Endpoint:**
- `POST /api/checkout` - Create order dari cart
  
**Request:**
```json
{
  "recipient_name": "John Doe",
  "recipient_phone": "081234567890",
  "recipient_address": "Jl. Merdeka No. 123, Bandung",
  "notes": "Tolong dikemas rapi",
  "order_items": []  // Akan diambil dari cart jika kosong
}
```

**Response (201):**
```json
{
  "message": "Pesanan berhasil dibuat",
  "code": "ORDER_CREATED",
  "order": {
    "id": 1,
    "order_number": "ORD-20260608143022-ABC123",
    "buyer_id": 1,
    "store_id": 1,
    "status": "Menunggu Pembayaran",
    "total_price": 100000,
    "created_at": "2026-06-08T14:30:22.000Z",
    "orderItems": [...],
    "payment": {
      "id": 1,
      "order_id": 1,
      "status": "Pending",
      "invoice_url": null
    }
  }
}
```

---

### 3️⃣ Phase 3: Payment Process
```
[Payment Gateway Screen]
    ↓
[Show Payment Methods]
    ├─ Bank Transfer
    ├─ E-Wallet
    └─ Credit Card
    ↓
[Select Payment Method]
    ↓
[User membayar via Xendit]
    ↓
[Payment Success]
    ↓
[Optional: Upload Proof]
    ↓
[Order Status Updates to "Menunggu Konfirmasi"]
```

**Endpoints:**
- `POST /api/payments/{orderId}/upload-proof` - Upload bukti pembayaran
- `GET /api/payments/{orderId}` - Get payment details
- `POST /api/payments/webhook` - Xendit webhook (auto update payment status)

**Upload Proof Request:**
```json
{
  "proof_image": "[base64_image_data]"
}
```

---

### 4️⃣ Phase 4: Order Tracking
```
[Order History]
    ↓
[View Order Details]
    ├─ Order ID & Number
    ├─ Status: Menunggu Konfirmasi / Dikonfirmasi / Diproses / Dikirim / Selesai
    ├─ Seller Info
    ├─ Items & Total
    ├─ Shipping Address
    └─ Payment Status
```

**Endpoints:**
- `GET /api/orders/buyer/history?page=1` - Get buyer's orders
- `GET /api/orders/{orderId}` - Get order details

---

### 5️⃣ Phase 5: Delivery & Confirmation
```
[Order Status: Dikirim]
    ↓
[Buyer receives package]
    ↓
[Buyer clicks "Confirm Receipt"]
    ↓
[Order Status: Selesai ✓]
    ↓
[Option to Review Product]
```

**Endpoint:**
- `PUT /api/orders/{orderId}/confirm-receipt` - Konfirmasi penerimaan

---

### 6️⃣ Phase 6: Optional - Cancel Order
```
[Order Status: Menunggu Pembayaran]
    ↓
[Buyer clicks "Cancel Order"]
    ↓
[Confirm Cancellation]
    ↓
[Order Status: Dibatalkan]
    ↓
[Stock restored]
```

**Endpoint:**
- `PUT /api/orders/{orderId}/cancel` - Cancel order

---

## 🏪 SELLER SIDE FLOW

### 1️⃣ Phase 1: View Incoming Orders
```
[Dashboard]
    ↓
[Click "Pesanan" Tab]
    ↓
[View Incoming Orders Grouped by Status]
    ├─ Menunggu Konfirmasi: 2
    ├─ Dikonfirmasi: 1
    ├─ Sedang Diproses: 3
    ├─ Sedang Dikirim: 5
    └─ Selesai: 10
```

**Endpoint:**
- `GET /api/seller/orders` - Get seller's orders dengan pagination

**Response:**
```json
{
  "message": "Pesanan masuk toko",
  "data": {
    "data": [
      {
        "id": 1,
        "order_number": "ORD-20260608143022-ABC123",
        "status": "Menunggu Konfirmasi",
        "buyer_id": 2,
        "total_price": 100000,
        "created_at": "2026-06-08T14:30:22.000Z",
        "buyer": {
          "id": 2,
          "name": "John Doe",
          "phone": "081234567890"
        },
        "orderItems": [
          {
            "product_id": 1,
            "product": {
              "id": 1,
              "name": "Kerupuk Kulit",
              "price": 50000
            },
            "quantity": 2,
            "unit_price": 50000,
            "subtotal": 100000
          }
        ]
      }
    ],
    "total": 15,
    "current_page": 1,
    "last_page": 2
  }
}
```

---

### 2️⃣ Phase 2: Review Payment Proof
```
[Click Order Detail]
    ↓
[View Order Information]
    ├─ Buyer Info
    ├─ Items
    ├─ Total Price
    └─ Payment Status
    ↓
[If Status: Menunggu Konfirmasi]
  ├─ See uploaded proof image
  └─ Options: Confirm / Reject Payment
    ↓
```

**Endpoints:**
- `GET /api/payments/{orderId}/proof` - Get payment proof
- `POST /api/payments/{orderId}/confirm` - Confirm payment (update order status to "Dikonfirmasi")
- `POST /api/payments/{orderId}/reject` - Reject payment (return to "Menunggu Pembayaran")

---

### 3️⃣ Phase 3: Update Order Status

```
[Order Detail Page]
    ↓
[Current Status: Dikonfirmasi]
    ↓
[Seller clicks "Update Status"]
    ↓
[Select New Status]
  ├─ Diproses
  ├─ Dikirim
  └─ Selesai
    ↓
[Save]
    ↓
[Status Updated ✓]
```

**Endpoint:**
- `PUT /api/orders/{orderId}/status` - Update order status

**Request:**
```json
{
  "status": "Diproses"  // atau Dikirim, Selesai, etc
}
```

**Status Transitions (valid for sellers):**
- Dikonfirmasi → Diproses ✓
- Diproses → Dikirim ✓
- Dikirim → Selesai (optional, auto selesai saat buyer confirm receipt)
- Dibatalkan ✓ (dengan alasan)

---

### 4️⃣ Phase 4: View Store Reports
```
[Dashboard]
    ↓
[Click "Laporan" Tab]
    ↓
[View Summary Cards]
  ├─ Total Pesanan
  ├─ Pesanan Selesai
  ├─ Pesanan Dibatalkan
  ├─ Pesanan Diproses
  ├─ Total Pendapatan
  └─ Perkiraan Pendapatan
    ↓
[Filter by Date Range]
    ↓
[Download Report]
```

**Endpoint:**
- `GET /api/reports/store?start_date=2026-06-01&end_date=2026-06-30` - Get store report

---

## 👨‍💼 ADMIN SIDE FLOW

### 1️⃣ View Platform Reports
```
[Admin Dashboard]
    ↓
[Click "Laporan Platform" Tab]
    ↓
[View Platform Statistics]
  ├─ Total Users (Pembeli + Penjual)
  ├─ Total Toko
  ├─ Total Produk
  ├─ Total Orders (All Status)
  ├─ Total Revenue
  ├─ Top Sellers
  ├─ Top Products
  ├─ Top Buyers
  └─ Monthly Breakdown
    ↓
[Filter by Date]
    ↓
```

**Endpoint:**
- `GET /api/reports/platform?start_date=2026-06-01&end_date=2026-06-30` - Get platform report

---

## 🔌 API ENDPOINTS SUMMARY

### Authentication
```
POST   /api/auth/register           - Register user
POST   /api/auth/login              - Login user
POST   /api/auth/logout             - Logout (protected)
GET    /api/auth/me                 - Get current user (protected)
```

### Products
```
GET    /api/products                - List all products
GET    /api/products/{id}           - Get product detail
GET    /api/products/search         - Search products
GET    /api/stores/{storeId}/products - Get products by store
POST   /api/products                - Create product (seller only)
PUT    /api/products/{id}           - Update product (seller only)
DELETE /api/products/{id}           - Delete product (seller only)
```

### Cart
```
GET    /api/cart                    - Get cart
POST   /api/cart/add                - Add to cart
PUT    /api/cart/{cartId}           - Update cart item
DELETE /api/cart/{cartId}           - Remove from cart
POST   /api/cart/clear              - Clear cart
```

### Orders (Buyer)
```
POST   /api/checkout                - Create order (checkout)
GET    /api/orders/buyer/history    - Get buyer's orders
GET    /api/orders/{id}             - Get order detail
PUT    /api/orders/{id}/confirm-receipt - Confirm receipt (buyer)
PUT    /api/orders/{id}/cancel      - Cancel order (buyer)
```

### Orders (Seller)
```
GET    /api/seller/orders           - Get seller's orders
PUT    /api/orders/{id}/status      - Update order status (seller)
```

### Payments
```
GET    /api/payments/{orderId}      - Get payment details
POST   /api/payments/{orderId}/upload-proof - Upload payment proof
POST   /api/payments/{orderId}/submit - Submit payment
GET    /api/payments/{orderId}/proof - Get proof image
POST   /api/payments/{orderId}/confirm - Confirm payment (seller)
POST   /api/payments/{orderId}/reject - Reject payment (seller)
POST   /api/payments/webhook        - Xendit webhook
```

### Reports
```
GET    /api/reports/buyer           - Buyer transaction report
GET    /api/reports/store           - Store report (seller only)
GET    /api/reports/platform        - Platform report (admin only)
```

---

## 🔐 Authorization Rules

### Buyer Actions
- ✓ Create order (checkout)
- ✓ View own orders & details
- ✓ Upload payment proof
- ✓ Confirm receipt
- ✓ Cancel order (only if "Menunggu Pembayaran")
- ✓ View own buyer report

### Seller Actions
- ✓ Create/edit/delete products
- ✓ View own incoming orders
- ✓ Update order status
- ✓ Confirm/reject payment
- ✓ View own store report

### Admin Actions
- ✓ View all platform reports
- ✓ Deactivate/delete products
- ✓ Moderate content

---

## 📊 Database Schema Overview

### Orders Table
```
id (PK)
order_number (unique) - ORD-20260608143022-ABC123
buyer_id (FK) -> Users
store_id (FK) -> Stores
status (enum) - Menunggu Pembayaran, Menunggu Konfirmasi, Dikonfirmasi, Diproses, Dikirim, Selesai, Dibatalkan
recipient_name
recipient_phone
delivery_address
notes
total_price
delivered_at (timestamp when status = Dikirim)
completed_at (timestamp when status = Selesai)
created_at
updated_at
```

### Order Items Table
```
id (PK)
order_id (FK) -> Orders
product_id (FK) -> Products
quantity
unit_price
subtotal
created_at
updated_at
```

### Payments Table
```
id (PK)
order_id (FK, unique) -> Orders
status - Pending, Confirmed, Paid, Rejected, Expired
payment_method
invoice_id (Xendit)
invoice_url (Xendit)
payment_status - PENDING, PAID, FAILED, EXPIRED
paid_at (timestamp when paid)
confirmed_at (timestamp when confirmed)
created_at
updated_at
```

---

## ✅ ERROR HANDLING

### Common Errors

| Error Code | HTTP | Message | Solution |
|---|---|---|---|
| `EMPTY_CART` | 422 | Keranjang kosong | Tambah produk ke cart terlebih dahulu |
| `PRODUCT_NOT_FOUND` | 422 | Produk tidak ditemukan | Refresh dan coba lagi |
| `INSUFFICIENT_STOCK` | 422 | Stok tidak cukup | Kurangi qty pesanan |
| `MULTIPLE_STORES` | 422 | Produk dari berbagai toko | Checkout dari satu toko saja |
| `INVALID_TOTAL` | 422 | Total harus > 0 | Check order items |
| `DELIVERY_ADDRESS_REQUIRED` | 422 | Alamat pengiriman wajib | Masukkan alamat pengiriman |
| `UNAUTHORIZED` | 401 | User tidak terautentikasi | Login terlebih dahulu |
| `FORBIDDEN` | 403 | Akses ditolak | Peran user tidak sesuai |
| `NOT_FOUND` | 404 | Pesanan tidak ditemukan | Cek ID pesanan |

---

## 🧪 Testing Checklist

### Buyer Flow
- [ ] Register & login sebagai pembeli
- [ ] Tambah produk ke cart
- [ ] Checkout dengan data lengkap
- [ ] Order created dengan status "Menunggu Pembayaran"
- [ ] Upload bukti pembayaran
- [ ] Lihat order di history
- [ ] Confirm receipt saat status Dikirim
- [ ] Cancel order saat Menunggu Pembayaran
- [ ] View buyer report

### Seller Flow
- [ ] Login sebagai penjual
- [ ] Lihat incoming orders
- [ ] Confirm payment dengan bukti
- [ ] Update status: Dikonfirmasi → Diproses → Dikirim
- [ ] View seller report
- [ ] Check revenue calculation

### Admin Flow
- [ ] Login sebagai admin
- [ ] View platform report
- [ ] Check total orders, revenue, etc
- [ ] Filter by date range

### Payment Flow
- [ ] Xendit webhook updates payment status
- [ ] Order status auto-updates
- [ ] Payment proof displays correctly
- [ ] Multiple payment methods work

### Error Handling
- [ ] Empty cart error
- [ ] Invalid products error
- [ ] Insufficient stock error
- [ ] Unauthorized access error
- [ ] Concurrent order updates

---

## 🚀 Deployment Checklist

- [ ] All migrations run successfully
- [ ] All tables created with correct schema
- [ ] API endpoints respond correctly
- [ ] Payment gateway (Xendit) configured
- [ ] Email notifications work
- [ ] All tests pass
- [ ] Error handling covers all edge cases
- [ ] Database backups configured
- [ ] CORS configured correctly
- [ ] Rate limiting enabled

---

## 📝 Notes

- Order flow adalah **sequential** - tidak bisa skip status
- Hanya pembeli yang bisa confirm receipt
- Hanya penjual yang bisa update status & confirm payment
- Admin hanya bisa view reports, tidak bisa edit order
- Timestamps (`delivered_at`, `completed_at`) automatically recorded
- Stock decremented saat order created, restored jika cancelled
- Payments use Xendit payment gateway (bank transfer, e-wallet, credit card)

---

**Last Updated:** 2026-06-08
**Version:** 1.0
