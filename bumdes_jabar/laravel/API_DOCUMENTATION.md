# BUMDes Jabar - Backend API Documentation

## Overview
BUMDes Jabar adalah platform marketplace digital yang menghubungkan Badan Usaha Milik Desa (BUMDes) di seluruh Jawa Barat. Backend ini dibangun menggunakan Laravel 11 dan menyediakan RESTful API untuk aplikasi mobile Flutter.

## Setup dan Instalasi

### Prerequisites
- PHP 8.2+
- MySQL 8.0+
- Composer
- Laravel 11

### Installation Steps

1. **Clone Repository**
   ```bash
   cd c:\laragon\www\bumdes_jabar\laravel
   ```

2. **Install Dependencies**
   ```bash
   composer install
   ```

3. **Copy Environment File**
   ```bash
   cp .env.example .env
   ```

4. **Generate Application Key**
   ```bash
   php artisan key:generate
   ```

5. **Configure Database** (.env)
   ```
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=bumdes_jabar
   DB_USERNAME=root
   DB_PASSWORD=
   ```

6. **Run Migrations**
   ```bash
   php artisan migrate
   ```

7. **Seed Database**
   ```bash
   php artisan db:seed
   ```

8. **Create Storage Symlink**
   ```bash
   php artisan storage:link
   ```

9. **Start Development Server**
   ```bash
   php artisan serve
   ```

Server akan berjalan di `http://localhost:8000`

## API Endpoints

### Authentication (Public)

#### Register User
- **Endpoint:** `POST /api/auth/register`
- **Description:** Mendaftarkan pengguna baru (Pembeli/Penjual/Admin)
- **Body:**
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "role": "Pembeli"
  }
  ```
- **Response (201):**
  ```json
  {
    "message": "User registered successfully. Please verify your email.",
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "Pembeli",
      "created_at": "2025-05-13T10:00:00Z"
    }
  }
  ```

#### Login
- **Endpoint:** `POST /api/auth/login`
- **Description:** Login pengguna dan dapatkan token
- **Body:**
  ```json
  {
    "email": "john@example.com",
    "password": "password123"
  }
  ```
- **Response (200):**
  ```json
  {
    "message": "Login berhasil",
    "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "Pembeli"
    }
  }
  ```

#### Logout
- **Endpoint:** `POST /api/auth/logout`
- **Auth Required:** Yes (Bearer Token)
- **Response (200):**
  ```json
  {
    "message": "Logout berhasil"
  }
  ```

### Profile Management

#### Get User Profile
- **Endpoint:** `GET /api/profile`
- **Auth Required:** Yes
- **Response (200):**
  ```json
  {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "081234567890",
    "address": "Jl. Merdeka No. 1",
    "role": "Pembeli",
    "photo_url": null,
    "store": null
  }
  ```

#### Update User Profile
- **Endpoint:** `PUT /api/profile`
- **Auth Required:** Yes
- **Body:**
  ```json
  {
    "name": "John Updated",
    "phone": "081234567890",
    "address": "Jl. Merdeka No. 2",
    "photo_url": "https://example.com/photo.jpg"
  }
  ```

#### Change Password
- **Endpoint:** `PUT /api/profile/password`
- **Auth Required:** Yes
- **Body:**
  ```json
  {
    "current_password": "old_password",
    "password": "new_password",
    "password_confirmation": "new_password"
  }
  ```

#### Get Store Profile (Seller)
- **Endpoint:** `GET /api/store`
- **Auth Required:** Yes (Penjual role)
- **Response (200):**
  ```json
  {
    "id": 1,
    "user_id": 2,
    "store_name": "BUMDes Sejahtera",
    "description": "Toko BUMDes penjual hasil pertanian",
    "village": "Desa Maju",
    "district": "Kecamatan Maju",
    "regency": "Kabupaten Bandung",
    "contact_phone": "082234567890",
    "bank_name": "BRI",
    "bank_account_number": "0123456789",
    "bank_account_holder": "BUMDes Sejahtera",
    "store_photo_url": "https://example.com/store.jpg",
    "is_active": true,
    "created_at": "2025-05-13T10:00:00Z"
  }
  ```

#### Create/Update Store Profile (Seller)
- **Endpoint:** `POST /api/store` or `PUT /api/store`
- **Auth Required:** Yes (Penjual role)
- **Body:**
  ```json
  {
    "store_name": "BUMDes Sejahtera",
    "description": "Toko BUMDes penjual hasil pertanian",
    "village": "Desa Maju",
    "district": "Kecamatan Maju",
    "regency": "Kabupaten Bandung",
    "contact_phone": "082234567890",
    "bank_name": "BRI",
    "bank_account_number": "0123456789",
    "bank_account_holder": "BUMDes Sejahtera",
    "store_photo_url": "https://example.com/store.jpg"
  }
  ```

### Products (Public)

#### Get All Categories
- **Endpoint:** `GET /api/categories`
- **Response (200):**
  ```json
  [
    {
      "id": 1,
      "name": "Pertanian & Perkebunan",
      "description": "Produk hasil pertanian dan perkebunan lokal"
    },
    {
      "id": 2,
      "name": "Kerajinan Tangan",
      "description": "Produk kerajinan tangan tradisional dan modern"
    }
  ]
  ```

#### Get Featured Products
- **Endpoint:** `GET /api/products/featured`
- **Response (200):**
  ```json
  {
    "message": "Produk unggulan",
    "data": [
      {
        "id": 1,
        "store_id": 1,
        "category_id": 1,
        "name": "Padi Organik Premium",
        "type": "produk",
        "price": 50000,
        "stock": 100,
        "description": "Padi organik berkualitas tinggi",
        "photo_url": "https://example.com/padi.jpg",
        "is_active": true,
        "store": {
          "id": 1,
          "store_name": "BUMDes Sejahtera"
        },
        "category": {
          "id": 1,
          "name": "Pertanian & Perkebunan"
        },
        "created_at": "2025-05-13T10:00:00Z"
      }
    ]
  }
  ```

#### Get Popular Stores
- **Endpoint:** `GET /api/stores/popular`
- **Response (200):**
  ```json
  {
    "message": "Toko BUMDes terpopuler",
    "data": [
      {
        "id": 1,
        "store_name": "BUMDes Sejahtera",
        "village": "Desa Maju",
        "order_count": 45
      }
    ]
  }
  ```

#### Search Products
- **Endpoint:** `GET /api/products/search?q=padi&category_id=1&min_price=30000&max_price=70000&page=1`
- **Query Parameters:**
  - `q`: Keyword pencarian (optional)
  - `category_id`: ID kategori (optional)
  - `min_price`: Harga minimum (optional)
  - `max_price`: Harga maksimum (optional)
  - `page`: Halaman (default: 1)
- **Response (200):**
  ```json
  {
    "message": "Hasil pencarian produk",
    "data": {
      "current_page": 1,
      "data": [...],
      "total": 25,
      "per_page": 12
    }
  }
  ```

#### Get Product Details
- **Endpoint:** `GET /api/products/{id}`
- **Response (200):**
  ```json
  {
    "message": "Detail produk",
    "data": {
      "id": 1,
      "store_id": 1,
      "category_id": 1,
      "name": "Padi Organik Premium",
      "type": "produk",
      "price": 50000,
      "stock": 100,
      "description": "Padi organik berkualitas tinggi",
      "photo_url": "https://example.com/padi.jpg",
      "is_active": true,
      "store": { "id": 1, "store_name": "BUMDes Sejahtera" },
      "category": { "id": 1, "name": "Pertanian & Perkebunan" },
      "reviews": [
        {
          "id": 1,
          "rating": 5,
          "comment": "Produk berkualitas bagus",
          "buyer": { "id": 2, "name": "Pembeli A" },
          "created_at": "2025-05-12T10:00:00Z"
        }
      ]
    }
  }
  ```

### Products Management (Seller Only)

#### Add New Product/Service
- **Endpoint:** `POST /api/products`
- **Auth Required:** Yes (Penjual role)
- **Body:**
  ```json
  {
    "name": "Padi Organik Premium",
    "category_id": 1,
    "type": "produk",
    "price": 50000,
    "stock": 100,
    "description": "Padi organik berkualitas tinggi",
    "photo_url": "https://example.com/padi.jpg"
  }
  ```

#### Update Product/Service
- **Endpoint:** `PUT /api/products/{id}`
- **Auth Required:** Yes (Penjual role)
- **Body:** (semua field optional)
  ```json
  {
    "name": "Padi Organik Premium Updated",
    "price": 55000,
    "stock": 80
  }
  ```

#### Delete Product/Service
- **Endpoint:** `DELETE /api/products/{id}`
- **Auth Required:** Yes (Penjual role)

### Shopping Cart

#### Get Cart Items
- **Endpoint:** `GET /api/cart`
- **Auth Required:** Yes
- **Response (200):**
  ```json
  {
    "message": "Keranjang belanja",
    "items": [
      {
        "id": 1,
        "user_id": 1,
        "product_id": 1,
        "quantity": 2,
        "product": {
          "id": 1,
          "name": "Padi Organik",
          "price": 50000,
          "stock": 100,
          "photo_url": "https://example.com/padi.jpg",
          "store": { "id": 1, "store_name": "BUMDes Sejahtera" }
        }
      }
    ],
    "total": 100000
  }
  ```

#### Add to Cart
- **Endpoint:** `POST /api/cart/add`
- **Auth Required:** Yes
- **Body:**
  ```json
  {
    "product_id": 1,
    "quantity": 2
  }
  ```

#### Update Cart Item
- **Endpoint:** `PUT /api/cart/{cartId}`
- **Auth Required:** Yes
- **Body:**
  ```json
  {
    "quantity": 5
  }
  ```

#### Remove from Cart
- **Endpoint:** `DELETE /api/cart/{cartId}`
- **Auth Required:** Yes

#### Clear Cart
- **Endpoint:** `POST /api/cart/clear`
- **Auth Required:** Yes

### Orders

#### Create Order
- **Endpoint:** `POST /api/orders`
- **Auth Required:** Yes (Pembeli)
- **Body:**
  ```json
  {
    "recipient_name": "John Doe",
    "delivery_address": "Jl. Merdeka No. 1, Desa Maju, Kec. Maju, Kab. Bandung",
    "notes": "Tolong dikirim cepat"
  }
  ```
- **Response (201):**
  ```json
  {
    "message": "Pesanan berhasil dibuat",
    "data": {
      "id": 1,
      "order_number": "ORD-20250513100000-ABCDEF",
      "buyer_id": 1,
      "store_id": 1,
      "status": "Menunggu Pembayaran",
      "recipient_name": "John Doe",
      "delivery_address": "Jl. Merdeka No. 1, Desa Maju...",
      "notes": "Tolong dikirim cepat",
      "total_price": 100000,
      "orderItems": [
        {
          "id": 1,
          "product_id": 1,
          "quantity": 2,
          "unit_price": 50000,
          "subtotal": 100000
        }
      ],
      "store": { "id": 1, "store_name": "BUMDes Sejahtera" }
    }
  }
  ```

#### Get Order Details
- **Endpoint:** `GET /api/orders/{id}`
- **Auth Required:** Yes
- **Response (200):**
  ```json
  {
    "message": "Detail pesanan",
    "data": { ...order details... }
  }
  ```

#### Get Buyer's Order History
- **Endpoint:** `GET /api/orders/buyer/history?page=1`
- **Auth Required:** Yes (Pembeli)
- **Response (200):**
  ```json
  {
    "message": "Riwayat pesanan pembeli",
    "data": { ...paginated orders... }
  }
  ```

#### Get Seller's Incoming Orders
- **Endpoint:** `GET /api/seller/orders?page=1`
- **Auth Required:** Yes (Penjual)
- **Response (200):**
  ```json
  {
    "message": "Pesanan masuk toko",
    "data": { ...paginated orders... }
  }
  ```

#### Update Order Status (Seller)
- **Endpoint:** `PUT /api/orders/{id}/status`
- **Auth Required:** Yes (Penjual)
- **Body:**
  ```json
  {
    "status": "Diproses"
  }
  ```
- **Valid Status:** "Menunggu Pembayaran", "Menunggu Konfirmasi", "Dikonfirmasi", "Diproses", "Dikirim", "Selesai", "Dibatalkan"

#### Confirm Receipt (Buyer)
- **Endpoint:** `PUT /api/orders/{id}/confirm-receipt`
- **Auth Required:** Yes (Pembeli)

### Payments

#### Get Payment Information
- **Endpoint:** `GET /api/payments/{orderId}`
- **Auth Required:** Yes
- **Response (200):**
  ```json
  {
    "message": "Detail pembayaran",
    "data": {
      "order_number": "ORD-20250513100000-ABCDEF",
      "total_amount": 100000,
      "bank_name": "BRI",
      "bank_account_number": "0123456789",
      "bank_account_holder": "BUMDes Sejahtera",
      "payment_status": "Pending"
    }
  }
  ```

#### Upload Payment Proof
- **Endpoint:** `POST /api/payments/{orderId}/upload-proof`
- **Auth Required:** Yes (Pembeli)
- **Content-Type:** multipart/form-data
- **Body:**
  ```
  proof_image: [file - max 5MB, format: JPG/PNG]
  ```
- **Response (200):**
  ```json
  {
    "message": "Bukti pembayaran berhasil diunggah",
    "data": {
      "payment_id": 1,
      "proof_image_url": "https://example.com/storage/payment-proofs/...",
      "status": "Pending"
    }
  }
  ```

#### Get Payment Proof (Seller)
- **Endpoint:** `GET /api/payments/{orderId}/proof`
- **Auth Required:** Yes (Penjual)

#### Confirm Payment (Seller)
- **Endpoint:** `POST /api/payments/{orderId}/confirm`
- **Auth Required:** Yes (Penjual)

#### Reject Payment (Seller)
- **Endpoint:** `POST /api/payments/{orderId}/reject`
- **Auth Required:** Yes (Penjual)
- **Body:**
  ```json
  {
    "reason": "Nominal transfer tidak sesuai"
  }
  ```

### Reviews

#### Add Review
- **Endpoint:** `POST /api/reviews`
- **Auth Required:** Yes (Pembeli, order harus status "Selesai")
- **Body:**
  ```json
  {
    "product_id": 1,
    "order_id": 1,
    "rating": 5,
    "comment": "Produk berkualitas bagus, pengiriman cepat"
  }
  ```

#### Get Product Reviews
- **Endpoint:** `GET /api/products/{productId}/reviews?page=1`
- **Response (200):**
  ```json
  {
    "message": "Ulasan produk",
    "average_rating": 4.5,
    "data": { ...paginated reviews... }
  }
  ```

#### Get My Reviews
- **Endpoint:** `GET /api/reviews/my?page=1`
- **Auth Required:** Yes (Pembeli)

#### Update Review
- **Endpoint:** `PUT /api/reviews/{reviewId}`
- **Auth Required:** Yes (Pembeli)

#### Delete Review
- **Endpoint:** `DELETE /api/reviews/{reviewId}`
- **Auth Required:** Yes (Pembeli)

### Reports

#### Get Buyer Report
- **Endpoint:** `GET /api/reports/buyer?start_date=2025-01-01&end_date=2025-05-31`
- **Auth Required:** Yes (Pembeli)
- **Query Parameters:**
  - `start_date`: Format YYYY-MM-DD (optional)
  - `end_date`: Format YYYY-MM-DD (optional)

#### Get Store Report
- **Endpoint:** `GET /api/reports/store?start_date=2025-01-01&end_date=2025-05-31`
- **Auth Required:** Yes (Penjual)

#### Get Platform Report
- **Endpoint:** `GET /api/reports/platform?start_date=2025-01-01&end_date=2025-05-31`
- **Auth Required:** Yes (Admin)

## Authentication

Semua endpoint yang membutuhkan autentikasi harus mengirim JWT token di header:

```
Authorization: Bearer {token}
```

Token diterima setelah login berhasil dan valid selama 24 jam.

## Error Handling

Response error mengikuti format berikut:

```json
{
  "message": "Error description",
  "error": "Detailed error (opsional)",
  "errors": {
    "field_name": ["Error message"]
  }
}
```

Common Status Codes:
- `200 OK`: Request berhasil
- `201 Created`: Resource berhasil dibuat
- `400 Bad Request`: Validation error
- `401 Unauthorized`: Token tidak valid atau expired
- `403 Forbidden`: User tidak memiliki permission
- `404 Not Found`: Resource tidak ditemukan
- `422 Unprocessable Entity`: Validation failed
- `500 Internal Server Error`: Server error

## Rate Limiting

Sistem menerapkan rate limiting untuk login:
- Maksimal 5 percobaan gagal dalam 5 menit

## File Upload

### Storage Configuration
- Default disk: `public`
- Path: `storage/app/public/`
- URL: `{APP_URL}/storage/{path}`

### Upload Types
- **Payment Proof**: `payment-proofs/`
- **Product Photo**: `products/`
- **Profile Photo**: `profiles/`
- **Store Photo**: `stores/`

### File Constraints
- Max size: 5 MB
- Allowed formats: JPG, PNG
- Validation: Dilakukan di server sebelum disimpan

## Development Notes

### Creating the Storage Symlink
```bash
php artisan storage:link
```

Ini membuat symlink dari `storage/app/public` ke `public/storage` sehingga file dapat diakses melalui HTTP.

### Running Tests
```bash
php artisan test
```

### Clearing Cache
```bash
php artisan cache:clear
php artisan route:cache
```

## Database

### Migrations
```bash
php artisan migrate              # Run all migrations
php artisan migrate:rollback     # Rollback last migration
php artisan migrate:reset        # Reset all migrations
php artisan migrate:refresh      # Rollback and re-run all
```

## End-to-End Verified Flow

The following flow has been successfully tested on this backend:

1. Verify buyer email:
   - `GET /api/email/verify/5/d72b2fe09458cc47e6b54f67d69bf4654e25d3e6`
   - Response: `{"message":"Email berhasil diverifikasi."}`
2. Login buyer:
   - `POST /api/auth/login`
   - Body: `{"email":"testbuyer@example.com","password":"Password123"}`
   - Response includes `token`
3. Add product to cart:
   - `POST /api/cart/add`
   - Body: `{"product_id":1,"quantity":2}`
   - Response: `Produk ditambahkan ke keranjang`
4. Create order from cart:
   - `POST /api/orders`
   - Body: `{"recipient_name":"Test Buyer","delivery_address":"Jl. Uji Coba No. 1, Desa Sukamaju","notes":"Pesan untuk uji end-to-end"}`
   - Response: `Pesanan berhasil dibuat`
5. Upload payment proof:
   - `POST /api/payments/3/upload-proof`
   - Multipart `proof_image=@temp-proof.png`
   - Response: `Bukti pembayaran berhasil diunggah`
6. Confirm payment as seller:
   - `POST /api/payments/3/confirm`
   - Response: `Pembayaran dikonfirmasi`
7. Update order status to shipped:
   - `PUT /api/orders/3/status`
   - Body: `{"status":"Dikirim"}`
8. Confirm receipt as buyer:
   - `PUT /api/orders/3/confirm-receipt`
   - Response: `Penerimaan dikonfirmasi`
9. Fetch completed order:
   - `GET /api/orders/3`
   - Order status is `Selesai`

## Sample cURL Requests

### Login Buyer
```bash
curl -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"email":"testbuyer@example.com","password":"Password123"}'
```

### Add to Cart
```bash
curl -X POST http://127.0.0.1:8000/api/cart/add \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"product_id":1,"quantity":2}'
```

### Upload Payment Proof
```bash
curl -X POST http://127.0.0.1:8000/api/payments/3/upload-proof \
  -H "Accept: application/json" \
  -H "Authorization: Bearer <token>" \
  -F "proof_image=@temp-proof.png"
```

### Confirm Payment (Seller)
```bash
curl -X POST http://127.0.0.1:8000/api/payments/3/confirm \
  -H "Accept: application/json" \
  -H "Authorization: Bearer <seller_token>"
```

### Confirm Receipt (Buyer)
```bash
curl -X PUT http://127.0.0.1:8000/api/orders/3/confirm-receipt \
  -H "Accept: application/json" \
  -H "Authorization: Bearer <token>"
```

### Database Relationships
- **users** (many) → **stores** (1)
- **users** (many) → **orders** (as buyer)
- **users** (many) → **carts** (1)
- **users** (many) → **reviews** (as buyer)
- **stores** (many) → **products** (1)
- **stores** (many) → **orders** (1)
- **products** (many) → **carts** (1)
- **products** (many) → **order_items** (1)
- **products** (many) → **reviews** (1)
- **orders** (many) → **order_items** (1)
- **orders** (one) → **payments** (1)
- **categories** (many) → **products** (1)

## Environment Variables

```env
APP_NAME=BUMDes Jabar
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bumdes_jabar
DB_USERNAME=root
DB_PASSWORD=

FILESYSTEM_DISK=public
```

## Support & Contact

Untuk pertanyaan atau masalah terkait API, silakan hubungi tim pengembang.

---

**Versi Dokumen:** 1.0  
**Update Terakhir:** May 13, 2025  
**Status:** Production Ready
