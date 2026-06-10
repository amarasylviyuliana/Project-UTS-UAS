# BUMDes Jabar - Marketplace Produk & Jasa Antar BUMDes di Jawa Barat

## Project Overview

BUMDes Jabar adalah platform marketplace digital berbasis web dan mobile yang menghubungkan Badan Usaha Milik Desa (BUMDes) di seluruh Jawa Barat untuk menjual produk unggulan dan menawarkan jasa lokal kepada masyarakat luas.

### Fitur Utama
- **Registrasi & Login**: Sistem autentikasi untuk Pembeli, Penjual (BUMDes), dan Admin
- **Manajemen Profil**: Update profil pengguna dan toko BUMDes
- **Kelola Produk & Jasa**: Seller dapat menambah, mengubah, dan menghapus katalog
- **Pencarian & Kategori**: Pembeli dapat mencari produk dengan filter kategori dan harga
- **Keranjang & Pemesanan**: Proses checkout dengan keranjang belanja
- **Pembayaran Manual**: Sistem pembayaran berbasis transfer bank dengan upload bukti
- **Riwayat Transaksi & Laporan**: Histori pesanan dan laporan untuk semua pengguna

## Tech Stack

- **Backend**: Laravel 11 (PHP 8.2)
- **Database**: MySQL 8.0
- **Authentication**: JWT Token via Laravel Sanctum
- **File Storage**: Local filesystem with public disk
- **API Format**: RESTful JSON API

## Project Structure

```
app/
├── Http/
│   └── Controllers/
│       ├── AuthController.php
│       ├── ProfileController.php
│       ├── ProductController.php
│       ├── CartController.php
│       ├── OrderController.php
│       ├── PaymentController.php
│       ├── ReviewController.php
│       └── ReportController.php
└── Models/
    ├── User.php
    ├── Store.php
    ├── Category.php
    ├── Product.php
    ├── Cart.php
    ├── Order.php
    ├── OrderItem.php
    ├── Payment.php
    └── Review.php

database/
├── migrations/
├── seeders/
│   ├── DatabaseSeeder.php
│   └── CategorySeeder.php
└── factories/

routes/
└── api.php

config/
├── database.php
└── filesystems.php

docker/
├── nginx/
│   └── default.conf
└── php/
    └── Dockerfile

docker-compose.yml
```

## Installation

### Prerequisites
- PHP 8.2+
- Composer
- MySQL 8.0+ (untuk setup lokal)
- Docker Desktop + Docker Compose (opsional, untuk deployment container)
- Git

### Opsi 1: Jalankan Secara Lokal (Laragon / XAMPP)

1. **Masuk ke direktori backend**
   ```bash
   cd c:\laragon\www\Project-UTS-UAS\bumdes_jabar\laravel
   ```

2. **Install dependencies**
   ```bash
   composer install
   ```

3. **Copy environment file**
   ```bash
   cp .env.example .env
   ```

4. **Generate application key**
   ```bash
   php artisan key:generate
   ```

5. **Configure database in .env**
   ```env
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=bumdes_jabar
   DB_USERNAME=root
   DB_PASSWORD=
   ```

6. **Create database**
   ```bash
   mysql -u root -e "CREATE DATABASE bumdes_jabar;"
   ```

7. **Run migrations**
   ```bash
   php artisan migrate
   ```

8. **Seed database with initial categories**
   ```bash
   php artisan db:seed
   ```

9. **Create storage symlink for file uploads**
   ```bash
   php artisan storage:link
   ```

10. **Start development server**
    ```bash
    php artisan serve
    ```

Server akan berjalan di `http://localhost:8000`

### Opsi 2: Jalankan dengan Docker Compose

1. **Masuk ke direktori backend**
   ```bash
   cd c:\laragon\www\Project-UTS-UAS\bumdes_jabar\laravel
   ```

2. **Build dan jalankan container**
   ```bash
   docker compose up --build
   ```

3. **Akses layanan**
   - Backend API: http://localhost:8000
   - phpMyAdmin: http://localhost:8080
   - Database MySQL: localhost:3306

4. **Untuk menghentikan container**
   ```bash
   docker compose down
   ```

5. **Untuk membersihkan volume database**
   ```bash
   docker compose down -v
   ```

## API Usage

### Base URL
```
http://localhost:8000/api
```

### Authentication
Semua endpoint yang membutuhkan autentikasi harus menyertakan Bearer Token di header:
```
Authorization: Bearer {token}
```

### Example: Register & Login

**Register User**
```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "role": "Pembeli"
  }'
```

**Login**
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

Response akan berisi token yang digunakan untuk permintaan berikutnya.

### Example: Search Products

```bash
curl -X GET "http://localhost:8000/api/products/search?q=padi&category_id=1" \
  -H "Accept: application/json"
```

Untuk dokumentasi lengkap API, lihat [API_DOCUMENTATION.md](./API_DOCUMENTATION.md)

## Database Schema

### Users Table
- Menyimpan data pengguna (Pembeli, Penjual, Admin)
- Field: id, name, email, password, role, phone, address, photo_url, etc.

### Stores Table
- Menyimpan data toko BUMDes (1 user = 1 store max)
- Field: id, user_id, store_name, description, village, district, regency, bank_details, etc.

### Products Table
- Menyimpan katalog produk/jasa
- Field: id, store_id, category_id, name, type, price, stock, description, photo_url, etc.

### Orders Table
- Menyimpan pesanan dari pembeli
- Field: id, order_number, buyer_id, store_id, status, recipient_name, delivery_address, total_price, etc.

### Order Items Table
- Menyimpan detail item dalam setiap pesanan
- Field: id, order_id, product_id, quantity, unit_price, subtotal

### Payments Table
- Menyimpan bukti pembayaran
- Field: id, order_id, proof_image_url, status, rejection_reason, etc.

### Reviews Table
- Menyimpan ulasan produk dari pembeli
- Field: id, product_id, buyer_id, order_id, rating, comment

### Categories Table
- Menyimpan kategori produk
- Field: id, name, description

### Carts Table
- Menyimpan item di keranjang belanja pembeli
- Field: id, user_id, product_id, quantity

## Common Commands

### Database
```bash
php artisan migrate              # Run all pending migrations
php artisan migrate:rollback     # Rollback last batch
php artisan migrate:reset        # Reset all migrations
php artisan migrate:refresh      # Reset and re-run all
php artisan db:seed              # Run seeders
```

### Development
```bash
php artisan serve                # Start development server
php artisan tinker               # Laravel REPL
php artisan cache:clear          # Clear application cache
php artisan route:list           # List all routes
docker compose up --build         # Run backend via Docker Compose
docker compose down               # Stop Docker Compose services
```

### Testing
```bash
php artisan test                 # Run test suite
php artisan test --filter=AuthTest  # Run specific test
```

## File Upload

### Storage Configuration
Files are stored in `storage/app/public/` and served via `{APP_URL}/storage/{path}`

### Upload Directories
- **payment-proofs/**: Bukti transfer pembayaran
- **products/**: Foto produk (untuk future use)
- **profiles/**: Foto profil pengguna (untuk future use)
- **stores/**: Foto toko (untuk future use)

### Upload Constraints
- Max file size: 5 MB
- Allowed formats: JPG, PNG
- Server-side validation on file type and size

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

## Security Features

- Password hashing dengan bcrypt
- JWT token authentication (valid 24 jam)
- Rate limiting untuk login (5 attempts in 5 minutes)
- HTTPS untuk production
- Input validation dan sanitization
- CORS support (konfigurable)
- File upload validation

## Performance Optimization

- Database indexing pada frequently queried columns
- Eager loading dengan Eloquent relationships
- Pagination untuk list endpoints
- Caching support (configurable)
- Query optimization dengan select specific columns

## Development Workflow

1. **Create migration**
   ```bash
   php artisan make:migration create_table_name
   ```

2. **Create model**
   ```bash
   php artisan make:model ModelName -m
   ```

3. **Create controller**
   ```bash
   php artisan make:controller ControllerName
   ```

4. **Run migrations**
   ```bash
   php artisan migrate
   ```

5. **Test endpoints**
   - Use Postman, Insomnia, atau curl

## Testing API

### Using Postman
1. Import collection dari dokumentasi
2. Set Bearer Token dari login response
3. Test setiap endpoint

### Using cURL
```bash
curl -X GET http://localhost:8000/api/categories \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json"
```

## Troubleshooting

### Database Connection Error
- Pastikan MySQL running
- Cek konfigurasi DB di .env
- Pastikan database sudah dibuat

### File Upload Error
- Cek permissions pada `storage/app/public/`
- Pastikan symlink sudah dibuat: `php artisan storage:link`
- Cek ukuran file tidak melebihi 5 MB

### Token Expired
- Login kembali untuk mendapatkan token baru
- Token valid selama 24 jam

## Production Deployment

1. Set `.env` APP_ENV ke `production`
2. Disable APP_DEBUG
3. Generate strong APP_KEY
4. Run database migrations
5. Optimize untuk production:
   ```bash
   php artisan optimize
   php artisan route:cache
   php artisan config:cache
   php artisan view:cache
   ```
6. Setup HTTPS certificate
7. Configure proper file permissions
8. Setup automated backups

## Contributing

1. Create feature branch
2. Make changes
3. Test thoroughly
4. Submit pull request

## License

This project is proprietary software for BUMDes Jabar.

## Support

Untuk dukungan dan pertanyaan, hubungi tim pengembang atau buka issue di repository.

## Project Team

- **Abdillah Syafiq Gaos**
- **Aril Zulfikar**
- **Amara Sylvi Yuliana**
- **Hilman**
- **Mochammad Adhi R**
- **Sheva Heizatul I**
- **Yunita Nur 'Aini**

---

**Last Updated**: June 10, 2026  
**Version**: 1.1  
**Status**: In Development / Docker-ready

## Laravel Sponsors

We would like to extend our thanks to the following sponsors for funding Laravel development. If you are interested in becoming a sponsor, please visit the [Laravel Partners program](https://partners.laravel.com).

### Premium Partners

- **[Vehikl](https://vehikl.com/)**
- **[Tighten Co.](https://tighten.co)**
- **[WebReinvent](https://webreinvent.com/)**
- **[Kirschbaum Development Group](https://kirschbaumdevelopment.com)**
- **[64 Robots](https://64robots.com)**
- **[Curotec](https://www.curotec.com/services/technologies/laravel/)**
- **[Cyber-Duck](https://cyber-duck.co.uk)**
- **[DevSquad](https://devsquad.com/hire-laravel-developers)**
- **[Jump24](https://jump24.co.uk)**
- **[Redberry](https://redberry.international/laravel/)**
- **[Active Logic](https://activelogic.com)**
- **[byte5](https://byte5.de)**
- **[OP.GG](https://op.gg)**

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
