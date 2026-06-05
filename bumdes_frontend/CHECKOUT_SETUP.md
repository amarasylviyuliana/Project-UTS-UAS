# Setup Checkout - BUMDes Frontend

## Masalah

Checkout tidak berfungsi karena backend belum dikonfigurasi dengan benar.

## Solusi

### 1. Setup Environment Backend

```bash
cd bumdes_frontend/backend
cp .env.example .env
```

Edit `.env`:
```env
APP_NAME=Bumdes
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bumdes
DB_USERNAME=root
DB_PASSWORD=

SANCTUM_STATEFUL_DOMAINS=localhost,localhost:59449
SESSION_DRIVER=cookie
SESSION_LIFETIME=120
```

### 2. Generate APP_KEY

```bash
php artisan key:generate
```

### 3. Setup Database

Buat database baru:
```sql
CREATE DATABASE bumdes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. Run Migrations & Seeding

```bash
php artisan migrate --seed
```

Ini akan membuat tabel dan seeder data:
- **Users**: `test@example.com` / `password123` (Pembeli)
- **Products**: 4 produk sample (ID: 1-4)

### 5. Start Backend Server

```bash
php artisan serve --port=8000
```

Backend akan berjalan di: `http://localhost:8000/api`

### 6. Test Checkout Flow

#### A. Login
**Request:**
```
POST http://localhost:8000/api/auth/login
Content-Type: application/json

{
  "email": "test@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "message": "Login berhasil.",
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "name": "Test User",
    "email": "test@example.com"
  }
}
```

#### B. Checkout
**Request:**
```
POST http://localhost:8000/api/checkout
Content-Type: application/json
Authorization: Bearer {token_dari_login}

{
  "total": 100000,
  "recipient_name": "John Doe",
  "recipient_phone": "081234567890",
  "recipient_address": "Jl. Merdeka No. 123, Bandung",
  "order_items": [
    {
      "product_id": 1,
      "quantity": 2,
      "unit_price": 25000
    },
    {
      "product_id": 3,
      "quantity": 1,
      "unit_price": 75000
    }
  ]
}
```

**Response (Success - 201):**
```json
{
  "message": "Pesanan berhasil dibuat.",
  "order": {
    "id": 1,
    "order_number": "ORD-20260601143022-ABC123",
    "status": "Menunggu Pembayaran",
    "total": 100000,
    "recipient_name": "John Doe",
    "recipient_phone": "081234567890",
    "recipient_address": "Jl. Merdeka No. 123, Bandung",
    "created_at": "2026-06-01 14:30:22",
    "items": [
      {
        "product": {
          "id": 1,
          "name": "Kerupuk Kulit Garut",
          "price": 25000,
          "stock": 15,
          "image_url": "https://picsum.photos/seed/kerupuk/400/300"
        },
        "quantity": 2,
        "unit_price": 25000
      }
    ]
  }
}
```

### 7. Verify Frontend

- Flutter app sudah dikonfigurasi untuk menghubung ke backend di `http://localhost:8000/api`
- Ketika checkout berhasil, app akan redirect ke **PaymentScreen** dengan data order
- Jika gagal, akan menampilkan error message

## Troubleshooting

### Error: "Produk di keranjang tidak valid"
- Pastikan Anda menggunakan produk dengan ID > 0
- Database seeding sudah dijalankan (akan membuat produk dengan ID 1-4)

### Error: "Validasi gagal"
- Pastikan semua field di request sesuai dengan requirement:
  - `total`: numeric, min 0
  - `recipient_name`: string, max 255
  - `recipient_phone`: string, max 32
  - `recipient_address`: string, max 1024
  - `order_items`: array of objects dengan `product_id` yang exists di database

### Error: "Produk tidak ditemukan"
- Run `php artisan migrate --seed` untuk memastikan produk sudah di database

### Error: "Token tidak valid"
- Pastikan token dari login endpoint digunakan di header `Authorization: Bearer {token}`

## Database Schema

### Orders Table
```
- id: int
- user_id: int (FK to users)
- order_number: string (unique)
- status: string (default: 'pending')
- total: decimal(12,2)
- recipient_name: string
- recipient_phone: string
- recipient_address: text
- payment_proof: string (nullable)
- bank_account: string (nullable)
- notes: text (nullable)
- created_at, updated_at: timestamps
```

### Order Items Table
```
- id: int
- order_id: int (FK to orders)
- product_id: int (FK to products)
- quantity: int
- unit_price: decimal(12,2)
- created_at, updated_at: timestamps
```

### Products Table
```
- id: int
- name: string
- price: decimal(12,2)
- stock: int (default: 0)
- image_url: string (nullable)
- description: text (nullable)
- created_at, updated_at: timestamps
```

## API Endpoints

| Method | Endpoint | Auth | Fungsi |
|--------|----------|------|--------|
| POST | `/auth/login` | No | Login user |
| POST | `/auth/register` | No | Register user |
| POST | `/auth/logout` | Yes | Logout user |
| GET | `/user` | Yes | Get current user |
| GET | `/products` | No | Get all products |
| POST | `/checkout` | Yes | Create order & checkout |
| GET | `/orders` | Yes | Get user's orders |
| POST | `/orders/{order}/payment-proof` | Yes | Upload payment proof |

## Notes

- Frontend sudah support multiple response shapes dari backend
- Order akan selalu dibuat dengan status "Menunggu Pembayaran"
- Total harus match dengan sum dari order_items
- Setiap produk harus exists di products table dengan ID yang valid
