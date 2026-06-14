# Data Alignment Documentation - BUMDes Jabar

## Overview
Dokumen ini menjelaskan struktur data yang telah diselaraskan antara User, Penjual (Seller), dan Admin untuk memastikan integritas dan konsistensi data di seluruh sistem.

## Data Structure & Relationships

### 1. User Model
**Struktur:**
- `id` - Primary Key
- `name` - Nama lengkap
- `email` - Email unik
- `password` - Password (hashed)
- `role` - Enum: 'Pembeli', 'Penjual', 'Admin'
- `phone` - Nomor telpon
- `address` - Alamat
- `photo_url` - URL foto profil
- `email_verified_at` - Timestamp verifikasi email
- `timestamps` - Created/Updated

**Relationships:**
- `hasOne(Store)` - Jika role = 'Penjual'
- `hasOne(Admin)` - Jika role = 'Admin'
- `hasOne(SellerVerification)` - Jika role = 'Penjual'
- `hasMany(Order)` - Sebagai pembeli (buyer_id)
- `hasMany(Cart)` - Keranjang belanja
- `hasMany(Review)` - Review yang dibuat

**Helper Methods:**
```php
$user->isAdmin()           // Cek apakah user adalah admin
$user->isSeller()          // Cek apakah user adalah penjual
$user->isBuyer()           // Cek apakah user adalah pembeli
$user->isVerifiedSeller()  // Cek apakah penjual terverifikasi
```

---

### 2. Admin Model (NEW)
**Tujuan:** Menyimpan data profile admin yang terpisah dari User

**Struktur:**
- `id` - Primary Key
- `user_id` - FK ke User (unique, cascade delete)
- `department` - Departemen/Divisi
- `job_title` - Jabatan
- `phone_internal` - Nomor internal
- `is_super_admin` - Boolean (true = akses penuh)
- `permissions` - JSON (custom permissions)
- `is_active` - Boolean (status aktif)
- `timestamps` - Created/Updated

**Relationships:**
- `belongsTo(User)` - User yang menjadi admin
- `hasMany(StoreApproval)` - Persetujuan toko yang di-handle
- `hasMany(ProductApproval)` - Persetujuan produk yang di-handle
- `hasMany(SellerVerification)` - Verifikasi penjual yang di-handle
- `hasMany(AuditLog)` - Log aksi admin

**Migrasi:**
Table `admins` dibuat di: `database/migrations/2026_06_12_000001_create_admins_table.php`

---

### 3. Store Model (Updated)
**Struktur Awal:** (tidak berubah)
- `id` - Primary Key
- `user_id` - FK ke User
- `store_name` - Nama toko
- `description` - Deskripsi toko
- `village` - Desa
- `district` - Kecamatan
- `regency` - Kabupaten
- `contact_phone` - Nomor kontak
- `bank_account_*` - Data perbankan
- `store_photo_url` - Foto toko
- `is_active` - Status aktif
- `timestamps` - Created/Updated

**Relationships (Updated):**
- `belongsTo(User)` - User yang memiliki toko
- `hasOne(StoreApproval)` - Persetujuan toko
- `hasOne(SellerVerification)` - Verifikasi penjual
- `hasMany(Product)` - Produk toko
- `hasMany(Order)` - Pesanan toko

**Helper Methods (NEW):**
```php
$store->isApproved()         // Cek apakah toko disetujui admin
$store->isPendingApproval()  // Cek apakah toko menunggu persetujuan
$store->isVerified()         // Cek apakah toko/penjual terverifikasi
```

---

### 4. StoreApproval Model (NEW)
**Tujuan:** Tracking persetujuan toko oleh admin

**Struktur:**
- `id` - Primary Key
- `store_id` - FK ke Store (unique, cascade delete)
- `admin_id` - FK ke Admin (restrict delete)
- `status` - Enum: 'Menunggu Persetujuan', 'Disetujui', 'Ditolak', 'Perlu Revisi'
- `notes` - Catatan tambahan
- `rejected_reason` - Alasan penolakan (jika ditolak)
- `approved_at` - Timestamp persetujuan
- `timestamps` - Created/Updated

**Relationships:**
- `belongsTo(Store)` - Toko yang disetujui
- `belongsTo(Admin)` - Admin yang menyetujui

**Migrasi:**
Table `store_approvals` dibuat di: `database/migrations/2026_06_12_000003_create_store_approvals_table.php`

---

### 5. SellerVerification Model (NEW)
**Tujuan:** Tracking verifikasi identitas penjual

**Struktur:**
- `id` - Primary Key
- `user_id` - FK ke User (cascade delete)
- `store_id` - FK ke Store (cascade delete)
- `status` - Enum: 'Menunggu Verifikasi', 'Terverifikasi', 'Ditolak', 'Direvisi'
- `verified_by` - FK ke Admin (set null jika dihapus)
- `verification_date` - Timestamp verifikasi
- `rejection_reason` - Alasan penolakan
- `document_url` - URL dokumen identitas
- `notes` - Catatan verifikasi
- `timestamps` - Created/Updated

**Relationships:**
- `belongsTo(User)` - User penjual
- `belongsTo(Store)` - Store penjual
- `belongsTo(Admin, 'verified_by')` - Admin yang verifikasi

**Migrasi:**
Table `seller_verifications` dibuat di: `database/migrations/2026_06_12_000002_create_seller_verifications_table.php`

---

### 6. ProductApproval Model (NEW)
**Tujuan:** Tracking persetujuan produk oleh admin

**Struktur:**
- `id` - Primary Key
- `product_id` - FK ke Product (unique, cascade delete)
- `admin_id` - FK ke Admin (restrict delete)
- `status` - Enum: 'Menunggu Persetujuan', 'Disetujui', 'Ditolak'
- `notes` - Catatan tambahan
- `rejected_reason` - Alasan penolakan
- `approved_at` - Timestamp persetujuan
- `timestamps` - Created/Updated

**Relationships:**
- `belongsTo(Product)` - Produk yang disetujui
- `belongsTo(Admin)` - Admin yang menyetujui

**Migrasi:**
Table `product_approvals` dibuat di: `database/migrations/2026_06_12_000004_create_product_approvals_table.php`

---

### 7. Product Model (Updated)
**Relationships (Added):**
- `hasOne(ProductApproval)` - Persetujuan produk

**Helper Methods (NEW):**
```php
$product->isApproved()         // Cek apakah produk disetujui
$product->isPendingApproval()  // Cek apakah produk menunggu persetujuan
$product->isRejected()         // Cek apakah produk ditolak
```

---

### 8. AuditLog Model (NEW)
**Tujuan:** Mencatat semua aksi admin untuk audit trail

**Struktur:**
- `id` - Primary Key
- `admin_id` - FK ke Admin (cascade delete)
- `action` - String: 'create', 'update', 'delete', 'approve', 'reject', etc.
- `model_type` - Tipe model yang diubah (e.g., 'Store', 'Product')
- `model_id` - ID model yang diubah
- `old_values` - JSON (data lama sebelum perubahan)
- `new_values` - JSON (data baru setelah perubahan)
- `ip_address` - IP address admin
- `user_agent` - User agent browser
- `created_at` - Timestamp aksi

**Relationships:**
- `belongsTo(Admin)` - Admin yang melakukan aksi

**Migrasi:**
Table `audit_logs` dibuat di: `database/migrations/2026_06_12_000005_create_audit_logs_table.php`

---

## Data Flow & Workflow

### 1. Pendaftaran Penjual
```
1. User mendaftar dengan role = 'Penjual'
2. User membuat/melengkapi Store
3. Admin verifikasi identitas → SellerVerification dibuat dengan status 'Menunggu Verifikasi'
4. Admin melakukan verifikasi → SellerVerification.status = 'Terverifikasi'
5. Admin menyetujui toko → StoreApproval dibuat dengan status 'Menunggu Persetujuan'
6. Admin menyetujui → StoreApproval.status = 'Disetujui'
7. Store.is_active = true (dapat berjualan)
```

### 2. Pengunggahan Produk
```
1. Penjual upload produk → Product dibuat
2. Admin review produk → ProductApproval dibuat dengan status 'Menunggu Persetujuan'
3. Admin approve/reject → ProductApproval.status diupdate
4. Jika disetujui, produk dapat dilihat pembeli
```

### 3. Admin Actions
```
Setiap aksi admin dicatat di:
- AuditLog (untuk audit trail)
- Model approval yang sesuai (untuk tracking persetujuan)
```

---

## Implementation Checklist

- [x] Buat Model Admin
- [x] Buat Model StoreApproval
- [x] Buat Model SellerVerification
- [x] Buat Model ProductApproval
- [x] Buat Model AuditLog
- [x] Update User model dengan relationships
- [x] Update Store model dengan relationships
- [x] Update Product model dengan relationships
- [x] Buat migrations untuk semua tabel baru
- [ ] Jalankan migrations: `php artisan migrate`
- [ ] Buat Controllers untuk approval & verification
- [ ] Update API endpoints
- [ ] Update Frontend untuk menampilkan approval status
- [ ] Buat seeder untuk admin test data

---

## Next Steps

1. **Jalankan Migrations:**
   ```bash
   php artisan migrate
   ```

2. **Buat Controllers untuk approval:**
   - `AdminController` - Manage admin users
   - `ApprovalController` - Handle store & product approvals
   - `VerificationController` - Handle seller verification

3. **Update API Routes:**
   - POST `/api/admin/verify-seller` - Verifikasi penjual
   - POST `/api/admin/approve-store` - Setujui toko
   - POST `/api/admin/approve-product` - Setujui produk
   - GET `/api/admin/audit-logs` - Lihat audit trail

4. **Update Frontend:**
   - Tampilkan verification status di profil penjual
   - Tampilkan approval status di toko dan produk
   - Admin dashboard untuk manage approvals

---

## Database Diagram

```
┌─────────────┐
│    User     │
├─────────────┤
│ id (PK)     │
│ name        │
│ email       │
│ role        │ ──→ 'Pembeli', 'Penjual', 'Admin'
│ password    │
│ phone       │
│ address     │
│ photo_url   │
└─────────────┘
      ↓
   ┌──┴──────────┬─────────────┐
   ↓             ↓             ↓
┌──────────┐  ┌───────┐  ┌────────────┐
│  Admin   │  │ Store │  │SellerVerif │
│ (1:1)    │  │(1:1)  │  │  (1:1)     │
└──────────┘  └───────┘  └────────────┘
    ↓             ↓
┌─────────┐  ┌──────────────┐
│ Audit   │  │StoreApproval │
│  Logs   │  │   (1:1)      │
└─────────┘  └──────────────┘
                  ↓
              ┌────────┐
              │Product │
              │ (1:M)  │
              └────────┘
                  ↓
              ┌──────────────┐
              │ProductApproval│
              │   (1:1)      │
              └──────────────┘
```

---

## Testing Data Alignment

### Query untuk memastikan data selaras:

```php
// Cek semua penjual yang terverifikasi
$verifiedSellers = User::where('role', 'Penjual')
    ->with('sellerVerification')
    ->whereHas('sellerVerification', fn($q) => $q->where('status', 'Terverifikasi'))
    ->get();

// Cek toko yang menunggu persetujuan
$pendingApprovals = Store::with('storeApproval')
    ->whereHas('storeApproval', fn($q) => $q->where('status', 'Menunggu Persetujuan'))
    ->get();

// Cek produk yang sudah disetujui
$approvedProducts = Product::with('productApproval')
    ->whereHas('productApproval', fn($q) => $q->where('status', 'Disetujui'))
    ->get();

// Cek audit trail admin tertentu
$adminActions = Admin::find(1)->auditLogs()->orderBy('created_at', 'desc')->get();
```

---

## Security Considerations

1. **Authorization Middleware:**
   - Hanya admin tertentu yang bisa approve/verify
   - Gunakan `can` & `authorize` di controller

2. **Audit Trail:**
   - Semua aksi admin dicatat di AuditLog
   - IP & User Agent disimpan untuk keamanan

3. **Data Validation:**
   - Validasi status enum sebelum save
   - Validasi foreign keys

4. **Approval Workflow:**
   - Tidak bisa approve jika sudah approved sebelumnya
   - Tidak bisa delete approved items

---

## Maintenance

Untuk menjaga data tetap selaras:

1. Rutin check integrity dengan query di atas
2. Monitor AuditLog untuk aktivitas mencurigakan
3. Backup database secara berkala
4. Jalankan integrity check command (akan dibuat di step berikutnya)
