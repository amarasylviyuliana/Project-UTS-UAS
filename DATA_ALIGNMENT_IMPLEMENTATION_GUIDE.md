# Data Alignment Implementation Guide

## 📋 Overview

Panduan ini menjelaskan langkah-langkah implementasi data alignment antara User, Penjual, dan Admin di sistem BUMDes Jabar.

---

## 🚀 Quick Start

### 1. Run Migrations

Jalankan migrasi database untuk membuat tabel-tabel baru:

```bash
cd bumdes_jabar/laravel
php artisan migrate
```

**Migrasi yang akan dijalankan:**
- `2026_06_12_000001_create_admins_table` - Tabel admin profile
- `2026_06_12_000002_create_seller_verifications_table` - Verifikasi penjual
- `2026_06_12_000003_create_store_approvals_table` - Persetujuan toko
- `2026_06_12_000004_create_product_approvals_table` - Persetujuan produk
- `2026_06_12_000005_create_audit_logs_table` - Log audit

### 2. Check Data Alignment

Setelah migrasi, cek apakah data sudah selaras:

```bash
php artisan data:check-alignment
```

Jika ada masalah, jalankan dengan flag `--fix`:

```bash
php artisan data:check-alignment --fix
```

---

## 📁 File Structure

### Models Created:
```
app/Models/
├── Admin.php                    # Admin profile model
├── AdminController.php          # Admin management controller
├── StoreApproval.php           # Store approval model
├── ProductApproval.php         # Product approval model
├── SellerVerification.php       # Seller verification model
└── AuditLog.php                # Audit log model
```

### Controllers Created:
```
app/Http/Controllers/Admin/
├── AdminController.php          # Manage admin users & dashboard
├── ApprovalController.php       # Handle store & product approvals
└── VerificationController.php   # Handle seller verification
```

### Commands Created:
```
app/Console/Commands/
└── CheckDataAlignment.php       # Data integrity check command
```

### Migrations Created:
```
database/migrations/
├── 2026_06_12_000001_create_admins_table.php
├── 2026_06_12_000002_create_seller_verifications_table.php
├── 2026_06_12_000003_create_store_approvals_table.php
├── 2026_06_12_000004_create_product_approvals_table.php
└── 2026_06_12_000005_create_audit_logs_table.php
```

### Models Updated:
```
app/Models/
├── User.php                     # Added: admin, sellerVerification relations
├── Store.php                    # Added: storeApproval, sellerVerification relations
└── Product.php                  # Added: productApproval relation
```

### Routes Updated:
```
routes/
└── api.php                      # Added: admin routes group
```

---

## 🔧 Configuration

### Middleware Setup

Pastikan middleware `role:Admin` sudah ada di `app/Http/Middleware/` directory. Jika belum, jalankan:

```bash
php artisan make:middleware CheckRole
```

Dan update file tersebut:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    public function handle(Request $request, Closure $next, string $role): Response
    {
        if ($request->user() && $request->user()->role === $role) {
            return $next($request);
        }

        return response()->json([
            'message' => 'Unauthorized - Admin access required'
        ], 403);
    }
}
```

Daftarkan di `bootstrap/app.php` atau `app/Http/Kernel.php`:

```php
protected $routeMiddleware = [
    // ... existing middleware
    'role' => \App\Http\Middleware\CheckRole::class,
];
```

---

## 📊 Data Workflow

### Workflow 1: Penjual Registration & Approval

```
┌─────────────────────────────────────────────────────────┐
│ 1. Calon Penjual Mendaftar                              │
│    - Buat akun dengan role='Penjual'                    │
│    - Lengkapi profil dan data toko                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 2. SellerVerification Created (Status: Menunggu)        │
│    - Admin menerima notifikasi                          │
│    - Admin review dokumen identitas                     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Admin Verify Seller                                  │
│    PUT /api/admin/verifications/{id}                    │
│    - Cek dokumen identitas                              │
│    - Update status → Terverifikasi/Ditolak/Direvisi    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 4. StoreApproval Created (Status: Menunggu)             │
│    - Admin review detail toko                           │
│    - Admin verifikasi lokasi dan informasi toko         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Admin Approve Store                                  │
│    PUT /api/admin/store-approvals/{id}                  │
│    - Update status → Disetujui/Ditolak/Perlu Revisi   │
│    - Store.is_active = true (jika disetujui)           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Penjual Aktif - Bisa Berjualan                       │
│    - Upload produk                                      │
│    - Produk menunggu persetujuan admin                  │
└─────────────────────────────────────────────────────────┘
```

### Workflow 2: Product Approval

```
┌─────────────────────────────────────────────────────────┐
│ 1. Penjual Upload Produk                                │
│    POST /api/products                                   │
│    - Product dibuat dengan is_active=false              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 2. ProductApproval Created                              │
│    Status: Menunggu Persetujuan                         │
│    - Admin notifikasi produk baru                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Admin Review Produk                                  │
│    GET /api/admin/product-approvals                     │
│    - Check detail produk                                │
│    - Cek foto & deskripsi sesuai aturan                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Admin Approve/Reject Produk                          │
│    PUT /api/admin/product-approvals/{id}                │
│    - Status → Disetujui/Ditolak                        │
│    - Product.is_active = true (jika disetujui)          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Produk Visible di Marketplace                        │
│    - Pembeli bisa lihat & beli produk                   │
│    - History tersimpan di AuditLog                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🔌 API Endpoints

### Admin Management

```
GET    /api/admin/admins                    # Get all admins
GET    /api/admin/admins/{id}              # Get admin detail
POST   /api/admin/admins                    # Create new admin
PUT    /api/admin/admins/{id}              # Update admin profile
GET    /api/admin/dashboard/stats           # Get dashboard stats
```

### Store Approvals

```
GET    /api/admin/store-approvals                    # Get pending approvals
GET    /api/admin/store-approvals/{id}              # Get approval detail
PUT    /api/admin/store-approvals/{id}              # Approve/reject store
```

**Request Body untuk PUT:**
```json
{
    "status": "Disetujui",  // atau "Ditolak", "Perlu Revisi"
    "notes": "Informasi toko lengkap dan valid",
    "rejected_reason": null  // jika status = Ditolak
}
```

### Product Approvals

```
GET    /api/admin/product-approvals                    # Get pending approvals
GET    /api/admin/product-approvals/{id}              # Get approval detail
PUT    /api/admin/product-approvals/{id}              # Approve/reject product
```

**Request Body untuk PUT:**
```json
{
    "status": "Disetujui",  // atau "Ditolak"
    "notes": "Produk sesuai standar",
    "rejected_reason": null  // jika status = Ditolak
}
```

### Seller Verification

```
GET    /api/admin/verifications                       # Get pending verifications
GET    /api/admin/verifications/{id}                 # Get verification detail
PUT    /api/admin/verifications/{id}                 # Verify seller
GET    /api/admin/seller/{userId}/verification-history  # Get history
```

**Request Body untuk PUT:**
```json
{
    "status": "Terverifikasi",  // atau "Ditolak", "Direvisi"
    "rejection_reason": null,    // jika status = Ditolak
    "notes": "Dokumen identitas sudah diverifikasi"
}
```

### Statistics & Monitoring

```
GET    /api/admin/approvals/stats          # Get approval statistics
GET    /api/admin/audit-logs               # Get all audit logs
GET    /api/admin/audit-logs/admin/{id}   # Get logs by admin
```

---

## 🧪 Testing API

### Example: Verify Seller

```bash
curl -X PUT http://localhost:8000/api/admin/verifications/1 \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "Terverifikasi",
    "notes": "Dokumen identitas sudah diverifikasi dengan baik"
  }'
```

### Example: Approve Store

```bash
curl -X PUT http://localhost:8000/api/admin/store-approvals/1 \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "Disetujui",
    "notes": "Toko sudah memenuhi semua persyaratan"
  }'
```

### Example: Reject Product

```bash
curl -X PUT http://localhost:8000/api/admin/product-approvals/1 \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "Ditolak",
    "rejected_reason": "Foto produk tidak sesuai standar"
  }'
```

---

## 📊 Database Queries

### Get verified sellers

```php
// In tinker atau controller
$verifiedSellers = User::where('role', 'Penjual')
    ->with(['store', 'sellerVerification'])
    ->whereHas('sellerVerification', fn($q) => $q->where('status', 'Terverifikasi'))
    ->paginate();
```

### Get pending approvals

```php
// Toko menunggu persetujuan
$pendingStores = Store::with('user', 'storeApproval')
    ->whereHas('storeApproval', fn($q) => $q->where('status', 'Menunggu Persetujuan'))
    ->get();

// Produk menunggu persetujuan
$pendingProducts = Product::with('store', 'productApproval')
    ->whereHas('productApproval', fn($q) => $q->where('status', 'Menunggu Persetujuan'))
    ->get();
```

### Get admin audit trail

```php
// Log aksi admin tertentu
$adminActions = Admin::find(1)
    ->auditLogs()
    ->with('admin.user')
    ->orderBy('created_at', 'desc')
    ->paginate();
```

---

## ✅ Verification Checklist

- [ ] Jalankan migrations: `php artisan migrate`
- [ ] Jalankan data alignment check: `php artisan data:check-alignment`
- [ ] Test admin endpoints dengan Postman/Insomnia
- [ ] Verify seller dengan API endpoint
- [ ] Approve store dan check is_active status
- [ ] Upload product dan check approval status
- [ ] Check audit logs untuk semua admin actions
- [ ] Update frontend untuk menampilkan approval status
- [ ] Setup email notifications untuk approval updates
- [ ] Create admin seeder untuk test data

---

## 🔐 Security Checklist

- [x] Middleware authorization (`role:Admin`)
- [x] Request validation di semua controllers
- [x] Audit trail logging untuk semua admin actions
- [x] Foreign key constraints (cascade/restrict)
- [x] JSON field untuk flexible permissions

**Belum diimplementasi (next steps):**
- [ ] Permission-based access control (per admin)
- [ ] Rate limiting untuk approval endpoints
- [ ] Email notifications
- [ ] Two-factor authentication untuk admin
- [ ] Admin activity monitoring dashboard

---

## 🐛 Troubleshooting

### Jika migration error:

```bash
# Rollback dan coba lagi
php artisan migrate:rollback
php artisan migrate

# Atau jika perlu reset semua
php artisan migrate:reset
php artisan migrate --seed
```

### Jika data tidak selaras:

```bash
# Check issues
php artisan data:check-alignment

# Fix automatically
php artisan data:check-alignment --fix

# Manual query check
php artisan tinker
>>> User::where('role', 'Admin')->whereDoesntHave('admin')->count()
```

### Jika API 403 Unauthorized:

- Pastikan user memiliki role='Admin'
- Pastikan token valid
- Pastikan User memiliki Admin profile

```bash
# Debug di tinker
php artisan tinker
>>> User::find(1)->role
>>> User::find(1)->admin  // harus ada
```

---

## 📚 Additional Resources

- [DATA_ALIGNMENT_DOCUMENTATION.md](../DATA_ALIGNMENT_DOCUMENTATION.md) - Dokumentasi lengkap struktur data
- [Laravel Documentation](https://laravel.com/docs)
- [Eloquent Relationships](https://laravel.com/docs/eloquent-relationships)

---

## 📞 Support

Untuk pertanyaan atau masalah, silakan:
1. Check troubleshooting section di atas
2. Review documentation files
3. Check console output untuk error messages
4. Run `php artisan data:check-alignment` untuk diagnosa
