# 🚀 Quick Start Guide - Order Flow Complete

**Status:** Ready to Use
**Last Updated:** 2026-06-08

---

## ⚡ Quick Start (5 Minutes)

### 1. Start Backend
```bash
cd bumdes_jabar/laravel
php artisan serve --port=8000
```
Check: `http://localhost:8000/api/products` returns JSON

### 2. Start Frontend
```bash
cd bumdes_frontend
flutter run -d chrome
```
App opens at `http://localhost:****` (check terminal for port)

### 3. Login & Test
**Seller Account:**
```
Email: seller@example.com
Password: password
```

**Buyer Account:**
```
Email: buyer@example.com
Password: password
```

---

## 📋 Complete Order Workflow

### BUYER: Place Order
1. Login as buyer
2. Browse products (Home page)
3. Add to cart
4. Checkout with delivery info
5. Pay via Xendit gateway
6. Receive order
7. Confirm receipt when arrives

### SELLER: Process Order
1. Login as seller
2. View "Pesanan" tab (incoming orders)
3. Review order details
4. Confirm payment (if manual upload)
5. Update status: Dikonfirmasi → Diproses → Dikirim
6. See buyer mark as complete

### ADMIN: View Reports
1. Login as admin
2. Dashboard shows platform statistics
3. Filter by date range
4. See top sellers, revenue, transactions

---

## 📁 Key Files

### Documentation
- `ORDER_FLOW_COMPLETE.md` - Full flow documentation
- `ORDER_FLOW_IMPROVEMENTS.md` - Enhancement guide
- `TESTING_AND_DEPLOYMENT.md` - Testing & deploy
- `IMPLEMENTATION_SUMMARY.md` - This summary

### Frontend Code
- `bumdes_frontend/lib/src/screens/order_detail_screen.dart` - Order detail
- `bumdes_frontend/lib/src/screens/seller_orders_screen.dart` - Seller orders
- `bumdes_frontend/lib/src/services/order_service.dart` - API calls
- `bumdes_frontend/lib/src/constants/order_status.dart` - Status constants

### Backend Code
- `bumdes_jabar/laravel/app/Http/Controllers/OrderController.php` - Orders
- `bumdes_jabar/laravel/app/Http/Controllers/PaymentController.php` - Payments
- `bumdes_jabar/laravel/app/Http/Controllers/ReportController.php` - Reports
- `bumdes_jabar/laravel/routes/api.php` - API routes

---

## 🧪 Quick Test

### Test 1: Create Order (2 minutes)
```
1. Login as buyer
2. Add product to cart
3. Checkout
4. See order created with "Menunggu Pembayaran" status
✓ Success: Order created
```

### Test 2: Update Status (3 minutes)
```
1. Login as seller
2. View order in Pesanan tab
3. Click "Konfirmasi Pesanan" → Status changes
4. Click "Pesanan Sedang Disiapkan" → Diproses
5. Click "Kirim Pesanan" → Dikirim
✓ Success: Status updated sequentially
```

### Test 3: Confirm Receipt (2 minutes)
```
1. Login as buyer
2. View order (should be "Dikirim" from seller update)
3. Click "Konfirmasi Penerimaan"
4. See status change to "Selesai"
✓ Success: Order completed
```

---

## 🔑 Key Features

✅ **Complete Order Lifecycle**
- Create → Pay → Process → Ship → Complete

✅ **Real-Time Status Updates**
- Seller updates reflected immediately
- Buyer sees changes on refresh

✅ **Secure Role-Based Access**
- Buyer sees own orders
- Seller sees store orders
- Admin sees all reports

✅ **Payment Processing**
- Xendit gateway integration
- Webhook auto-confirmation
- Manual proof upload option

✅ **Comprehensive Reporting**
- Buyer transaction reports
- Seller store reports
- Admin platform reports

---

## 🆘 Troubleshooting

### App won't start
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Backend returns 404
```bash
# Check API running
curl http://localhost:8000/api/products

# Check migrations
php artisan migrate:status
```

### Login fails
```bash
# Check user exists
php artisan tinker
> User::where('email', 'buyer@example.com')->first()

# Reset password if needed
php artisan tinker
> User::where('email', 'buyer@example.com')->update(['password' => Hash::make('password')])
```

### No orders showing
```bash
# Check seller has store
php artisan tinker
> User::find(2)->store

# Check products exist
> Product::count()

# Create test data if needed
php artisan db:seed
```

---

## 📞 Support

**Need More Details?**
- See `ORDER_FLOW_COMPLETE.md` for detailed explanation
- See `TESTING_AND_DEPLOYMENT.md` for comprehensive testing guide
- See `ORDER_FLOW_IMPROVEMENTS.md` for known issues

---

## ✅ Success Indicators

When working correctly you should see:

1. ✅ Buyer can checkout and order appears in database
2. ✅ Order status can be updated by seller
3. ✅ Buyer sees status changes
4. ✅ Final order status is "Selesai" after buyer confirms
5. ✅ Order appears in seller/buyer/admin reports
6. ✅ No errors in browser console
7. ✅ No errors in Laravel logs

If all ✅ then ORDER FLOW IS WORKING CORRECTLY!

---

**Ready to Start?** 
1. Start backend: `php artisan serve --port=8000`
2. Start frontend: `flutter run -d chrome`
3. Login & test
4. Refer to documentation for details

**Happy Testing!** 🎉
