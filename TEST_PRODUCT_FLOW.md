# Test Seller Product Creation Flow

## Prerequisites
- Laravel backend running on http://127.0.0.1:8000
- MySQL database running
- Flutter app ready to test

## Test Scenario: Seller Adds Product

### Step 1: Login as Seller
1. Run Flutter app
2. Go to login screen
3. Login with Penjual role credentials:
   - Email: penjual@test.com (or any seller account)
   - Password: password
4. Verify authenticated as Penjual role

### Step 2: Navigate to Dashboard
1. After login, should see StoreDashboardScreen
2. Verify "Penjual BUMDes" shown in header

### Step 3: Add Product
1. Click "Katalog" or bottom nav "Produk" tab
2. Click "Tambah" button
3. Fill form:
   - Nama: "Sayuran Organik" (or any name)
   - Kategori: "Pertanian & Perkebunan"
   - Tipe: "Produk Fisik"
   - Harga: "50000"
   - Stok: "100"
   - Deskripsi: "Sayuran organik segar dari kebun lokal"
4. Click "Simpan"

### Expected Results:
- ✅ Success message appears: "Produk berhasil ditambahkan"
- ✅ Product returns to catalog view
- ✅ New product appears in seller's product list
- ✅ Product has ID from backend (not just timestamp)

### Step 4: Verify Persistence
1. Close and reopen app (or restart)
2. Login again as seller
3. Go to "Katalog" tab
4. **Expected**: New product "Sayuran Organik" still appears
5. **If fails**: Product was only stored locally, not in backend

### Step 5: Verify Buyer Can See Product
1. Logout from seller account
2. Login as Pembeli (buyer)
3. Browse home screen / products list
4. **Expected**: "Sayuran Organik" appears in buyer's product list
5. **If fails**: Product exists on seller but not visible to buyers

### Step 6: Test Seller Orders
1. Switch back to Penjual (seller) account
2. Go to "Pesanan" tab (Orders)
3. **Expected**: Shows real order data from backend
4. **If fails**: Shows loading spinner or empty list (that's OK if no orders)

## Debugging Tips

### Check if Product Posted Successfully
```sql
-- In MySQL, check if product was created:
SELECT * FROM products WHERE name = 'Sayuran Organik' LIMIT 1;
```

### Check API Response
- Look at Flutter console/debug output
- ProductService.createProduct() should log success/error
- Check Laravel logs: storage/logs/laravel.log

### Common Issues
1. **Product not persisting**: Check if ProductService.createProduct() is being called
2. **No authentication**: Verify token is being passed from AuthProvider
3. **Backend validation fails**: Check Laravel log for validation errors
4. **Network error**: Verify API_BASE_URL in config.dart is correct

## Success Criteria
- ✅ Product persists after app restart
- ✅ Product visible to buyers
- ✅ Orders tab shows real data from backend
- ✅ No mock/hardcoded data in dashboard
