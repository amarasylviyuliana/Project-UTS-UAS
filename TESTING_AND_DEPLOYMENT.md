# 🧪 Order Flow Testing & Deployment Guide

**Status:** Ready for Testing & Deployment
**Version:** 1.0
**Last Updated:** 2026-06-08

---

## ✅ Pre-Deployment Checklist

### Backend Setup
- [ ] Laravel `.env` configured dengan database
- [ ] Database migrations sudah dijalankan: `php artisan migrate`
- [ ] Seeder data sudah dijalankan: `php artisan db:seed` (atau buat test users)
- [ ] Xendit API keys configured di `.env`:
  - `XENDIT_SECRET_KEY` = xnd_secret_...
  - `XENDIT_PUBLIC_KEY` = xnd_public_...
  - `XENDIT_WEBHOOK_TOKEN` = webhook_token_value
- [ ] CORS configured untuk frontend URL
- [ ] Storage folder writable untuk payment proofs

### Frontend Setup
- [ ] Flutter dependencies installed: `flutter pub get`
- [ ] API endpoints di `config.dart` pointing ke backend
- [ ] Xendit public key available di payment gateway screen
- [ ] No compilation errors: `flutter analyze`

### Test Data Setup
- [ ] Admin user created (role='Admin')
- [ ] Seller user created (role='Penjual') dengan store
- [ ] Buyer user created (role='Pembeli')
- [ ] Sample products created di seller's store
- [ ] Bank account info di store (untuk payment manual)

---

## 🚀 Running the Application

### Terminal 1: Backend (Laravel)
```bash
cd bumdes_jabar/laravel

# Option A: Using Laragon (if installed)
# Just start from Laragon dashboard, or:
php artisan serve --port=8000

# Or if using built-in server
php -S https://project-uts-uas-production.up.railway.app -t public
```

### Terminal 2: Frontend (Flutter Web)
```bash
cd bumdes_frontend

# Run di Chrome (web)
flutter run -d chrome

# Or di specific port
flutter run -d chrome --web-port=6006
```

**Expected URLs:**
- Backend API: `https://project-uts-uas-production.up.railway.app/api`
- Frontend Web: `http://localhost:6006` (or default port)

---

## 🧪 Testing Scenarios

### Scenario 1: Complete Buyer Flow (Xendit Payment)

**Prerequisites:**
- Buyer logged in
- Seller has products
- Xendit configured

**Steps:**

1. **Browse Products**
   - Go to Home
   - See products list
   - Check product details

2. **Add to Cart**
   - Click "Tambah ke Keranjang"
   - See cart count increase
   - Go to Cart

3. **Checkout**
   ```
   Go to Cart → Checkout
   Fill:
   - Nama Penerima: "John Doe"
   - No. HP: "081234567890"  
   - Alamat: "Jl. Merdeka 123, Bandung"
   - Catatan: (optional)
   Click: "Checkout Sekarang"
   ```
   
   **Expected:**
   - Order created dengan status "Menunggu Pembayaran"
   - Redirect ke Payment Gateway Screen
   - Order ID displayed

4. **Payment via Xendit**
   ```
   Payment Gateway Screen:
   - See order details
   - Click "Bayar dengan Xendit"
   - Select payment method (VA/E-Wallet/CC)
   - Complete payment
   - Return to app
   ```
   
   **Expected:**
   - Order status changes to "Dikonfirmasi" (auto)
   - See "Pembayaran Berhasil" message
   - Redirect to Order Detail

5. **Track Order**
   ```
   Order Detail Screen:
   - See order number & total
   - See status: "Dikonfirmasi"
   - See items list
   - Refresh untuk update status
   ```

6. **Confirm Receipt (when shipped)**
   ```
   When seller updates status to "Dikirim":
   - See "Konfirmasi Penerimaan" button
   - Click button
   ```
   
   **Expected:**
   - Order status: "Selesai"
   - Receipt confirmed
   - Can now review product

**Check Points:**
- ✓ Order created correctly
- ✓ Payment processed via Xendit
- ✓ Status auto-updated to Dikonfirmasi
- ✓ Buyer can confirm receipt
- ✓ Order marked as Selesai

---

### Scenario 2: Complete Seller Flow

**Prerequisites:**
- Seller logged in
- Has incoming orders from scenario 1
- Buyer sudah upload payment proof atau Xendit already paid

**Steps:**

1. **View Incoming Orders**
   ```
   Seller Dashboard → Pesanan Tab
   OR
   Bottom Nav → Pesanan
   ```
   
   **Expected:**
   - See list of incoming orders
   - Shows status badges
   - Order counts grouped by status

2. **View Order Detail**
   ```
   Click on order from list
   ```
   
   **Expected:**
   - See buyer info
   - See items & total
   - See shipping address
   - See order status

3. **Confirm Payment (if Xendit already paid)**
   ```
   If order status "Menunggu Konfirmasi":
   - Payment already confirmed by Xendit
   - Click "Konfirmasi Pesanan" button
   ```
   
   **Expected:**
   - Order status → "Dikonfirmasi"
   - Message: "Status pesanan diperbarui"

4. **Update to Processing**
   ```
   When order "Dikonfirmasi":
   - Click "Pesanan Sedang Disiapkan"
   - (Optional intermediate step)
   ```
   
   **Expected:**
   - Status → "Diproses"

5. **Ship Order**
   ```
   When ready to ship:
   - Click "Kirim Pesanan"
   ```
   
   **Expected:**
   - Status → "Dikirim"
   - delivered_at timestamp recorded
   - Buyer sees "Konfirmasi Penerimaan" button

6. **View Store Report**
   ```
   Seller Dashboard → Laporan Tab
   ```
   
   **Expected:**
   - See summary stats
   - Total pesanan, selesai, pending, dll
   - Revenue calculation
   - Monthly breakdown

**Check Points:**
- ✓ Seller sees incoming orders
- ✓ Can confirm payment (if needed)
- ✓ Can update order status sequentially
- ✓ Status transitions work correctly
- ✓ Seller reports accurate

---

### Scenario 3: Admin Platform Reports

**Prerequisites:**
- Admin logged in
- Multiple completed orders exist

**Steps:**

1. **View Admin Dashboard**
   ```
   Admin Dashboard Screen
   ```
   
   **Expected:**
   - See platform statistics
   - Total users (buyers+sellers)
   - Total stores & products
   - Total transactions & revenue
   - Top sellers list

2. **Filter by Date**
   ```
   Select date range:
   - Start date: 2026-06-01
   - End date: 2026-06-08
   - Click Filter/Segarkan
   ```
   
   **Expected:**
   - Reports update dengan filtered data
   - Shows transactions dalam date range

3. **View Breakdowns**
   ```
   Scroll down untuk:
   - Daily transaction breakdown
   - Monthly revenue
   - Top stores
   ```

**Check Points:**
- ✓ Admin can access reports
- ✓ Statistics are accurate
- ✓ Date filtering works
- ✓ Top sellers calculated correctly

---

## 🔍 Error Scenarios Testing

### Test Case 1: Empty Cart Checkout
```
Steps:
1. Go to Cart (empty)
2. Click Checkout

Expected:
- Error message: "Keranjang kosong"
- Cannot proceed
```

### Test Case 2: Insufficient Stock
```
Steps:
1. Product with stock 2
2. Add to cart qty 5
3. Checkout

Expected:
- Error: "Stok produk tidak cukup"
- Suggested qty shown
```

### Test Case 3: Order from Multiple Stores
```
Steps:
1. Add product dari store A
2. Add product dari store B
3. Checkout

Expected:
- Error: "Anda hanya dapat memesan dari satu toko sekaligus"
- Show store count
```

### Test Case 4: Order Cancellation
```
Steps:
1. Create order (status: Menunggu Pembayaran)
2. Click "Batalkan Pesanan"
3. Confirm

Expected:
- Status → Dibatalkan
- Stock restored
- Cannot continue payment
```

### Test Case 5: Unauthorized Access
```
Steps:
1. Buyer tries to view seller order
2. Buyer tries to update order status
3. Non-admin tries to view platform report

Expected:
- All return 403 Forbidden
- Clear error messages
```

---

## 📊 Database Verification

### Check Orders Table
```sql
-- All orders created
SELECT id, order_number, buyer_id, store_id, status, total_price, created_at FROM orders;

-- Orders by status
SELECT status, COUNT(*) as count FROM orders GROUP BY status;

-- Recent completed orders
SELECT * FROM orders WHERE status = 'Selesai' ORDER BY completed_at DESC LIMIT 10;

-- Check timestamps
SELECT id, status, delivered_at, completed_at FROM orders WHERE delivered_at IS NOT NULL OR completed_at IS NOT NULL;
```

### Check Payments Table
```sql
-- Payment status
SELECT order_id, status, payment_status, paid_at, confirmed_at FROM payments;

-- Payment proofs
SELECT order_id, proof_image_url, confirmed_at FROM payments WHERE proof_image_url IS NOT NULL;

-- Xendit payments
SELECT order_id, invoice_id, invoice_url, payment_status FROM payments WHERE invoice_id IS NOT NULL;
```

### Check Order Items
```sql
-- Verify items
SELECT o.id, o.order_number, oi.product_id, oi.quantity, oi.unit_price, oi.subtotal 
FROM orders o 
JOIN order_items oi ON o.id = oi.order_id 
LIMIT 20;

-- Check stock updates
SELECT id, name, stock FROM products WHERE stock != initial_stock;
```

---

## 🔐 Security Testing

### Test 1: Authorization
```
- Buyer can't see other buyer's orders ✓
- Seller can't see other seller's orders ✓
- Non-seller can't update order status ✓
- Non-admin can't view admin reports ✓
```

### Test 2: Data Validation
```
- Can't checkout dengan negative quantity ✓
- Can't checkout dengan invalid products ✓
- Can't update with invalid status ✓
- Can't confirm receipt if not "Dikirim" ✓
```

### Test 3: Token Validation
```
- Invalid token rejected ✓
- Expired token refreshed ✓
- Missing token returns 401 ✓
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "Order tidak ditemukan"
**Cause:** Order ID invalid atau user tidak punya akses
**Solution:**
- Check order exists di database
- Check user ID matches buyer_id atau seller's store
- Check token valid

### Issue 2: "Status harus X untuk melakukan ini"
**Cause:** Invalid status transition
**Solution:**
- Check current order status
- Refer ke status transition diagram
- Ensure sequential updates

### Issue 3: Payment tidak auto-update
**Cause:** Xendit webhook tidak dipanggil
**Solution:**
- Check webhook token di .env
- Check webhook URL configured di Xendit dashboard
- Check logs untuk webhook errors

### Issue 4: Stock tidak berkurang
**Cause:** Order creation failed atau stock logic broken
**Solution:**
- Check order item creation successful
- Verify product type = 'produk' (not 'layanan')
- Check product exists dan is_active

### Issue 5: Orders tidak tampil di seller
**Cause:** Seller tidak punya store atau role wrong
**Solution:**
- Check seller role = 'Penjual'
- Check user has associated store
- Check store_id di orders matches

---

## 📈 Performance Optimization

### For Large Datasets
```dart
// Use pagination
const pageSize = 10;
final orders = await api.get('/seller/orders?page=1&per_page=$pageSize');

// Filter on backend not frontend
await api.get('/seller/orders?status=Dikirim');

// Load only needed fields
// Already done: include product, buyer, items only
```

### Database Optimization
```sql
-- Add indexes (already in migrations, but verify)
ALTER TABLE orders ADD INDEX idx_buyer_id (buyer_id);
ALTER TABLE orders ADD INDEX idx_store_id (store_id);
ALTER TABLE orders ADD INDEX idx_status (status);
ALTER TABLE payments ADD INDEX idx_order_id (order_id);
```

---

## 📝 Logging & Monitoring

### Backend Logging
```
Check Laravel logs: storage/logs/laravel-*.log
Look for:
- Order creation errors
- Payment processing errors
- Webhook processing
- Authorization failures
```

### Frontend Logging
```dart
// Enable debug logging
flutter run -d chrome --verbose

// Check Flutter logs for:
- API request/response
- Status updates
- Payment flow errors
- Navigation issues
```

---

## 🎯 Final Verification

Before marking as COMPLETE:

- [ ] All buyer flows work end-to-end
- [ ] All seller flows work end-to-end  
- [ ] All admin reports display correctly
- [ ] Error handling shows proper messages
- [ ] No crashes atau exceptions
- [ ] Stock updates correctly
- [ ] Payment status sync works
- [ ] Status transitions follow rules
- [ ] Authorization enforced
- [ ] Database records created accurately
- [ ] Timestamps recorded correctly
- [ ] Performance acceptable
- [ ] No SQL errors
- [ ] No API errors (4xx/5xx)
- [ ] No Flutter compilation errors

---

## 🚀 Deployment Steps

### 1. Backend Deployment
```bash
# Prepare
cd bumdes_jabar/laravel
php artisan config:cache
php artisan route:cache
php artisan optimize

# Deploy
git add . && git commit -m "Order flow implementation complete"
git push

# On server:
git pull
php artisan migrate --force
php artisan queue:work (if using queues)
```

### 2. Frontend Deployment
```bash
cd bumdes_frontend

# Build web
flutter build web --release

# Deploy to hosting
# Files in: build/web/

# Or via app store:
# Android: flutter build apk --release
# iOS: flutter build ios --release
```

### 3. Testing on Production
```
- Create test account
- Complete full order flow
- Monitor logs for errors
- Check database for records
- Verify payment processing
```

---

## 📞 Support & Troubleshooting

**If testing fails:**
1. Check all prerequisites installed
2. Verify database connected
3. Check API endpoints accessible
4. Review logs for errors
5. Verify Xendit API keys (if payment testing)
6. Check CORS configuration
7. Ensure Flutter version compatible

**Helpful Commands:**
```bash
# Check backend status
curl -i https://project-uts-uas-production.up.railway.app/api/products

# Check migrations
php artisan migrate:status

# Clear cache
php artisan cache:clear

# Restart Flutter
flutter clean && flutter pub get && flutter run -d chrome
```

---

**Document created:** 2026-06-08
**Status:** Ready for Testing
**Next step:** Execute test scenarios and verify all work correctly
