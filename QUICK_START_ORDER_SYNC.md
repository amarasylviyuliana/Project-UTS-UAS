# 🚀 QUICK START GUIDE - ORDER CANCELLATION & SYNC SYSTEM

## What Was Built

### ✅ Order Cancellation
- Pembeli dapat membatalkan pesanan dengan status "Belum Dibayar" (Menunggu Pembayaran)
- Status otomatis berubah menjadi "Dibatalkan"
- Stok produk langsung dikembalikan
- Semua perubahan dalam atomic database transaction

### ✅ Real-Time Sync System
- Dashboard pembeli, penjual, dan admin otomatis sync ketika pesanan dibatalkan
- Polling mechanism: setiap 30 detik (configurable)
- Snackbar notification ketika ada pembatalan
- Pull-to-refresh masih tersedia

### ✅ Clean Dashboard
- "Contoh data" badge hanya muncul di development mode
- Production dashboard tampil profesional tanpa placeholder
- Sample data hanya fallback jika API error

---

## Files to Review

### 1. Backend Changes (Laravel)

**New Files:**
- `bumdes_jabar/laravel/app/Events/OrderCancelled.php` - Event untuk broadcast pembatalan
- `bumdes_jabar/laravel/app/Events/OrderStatusUpdated.php` - Event untuk broadcast status update

**Modified Files:**
- `bumdes_jabar/laravel/app/Http/Controllers/OrderController.php`
  - Look for: `event(new OrderCancelled($order));` in `cancelOrder()`
  - Look for: `event(new OrderStatusUpdated(...))` in `updateStatus()`
  - New methods: `getBuyerOrdersSync()`, `getSellerOrdersSync()`

- `bumdes_jabar/laravel/routes/api.php`
  - New routes: `/api/orders/buyer/sync`, `/api/seller/orders/sync`

- `bumdes_jabar/laravel/routes/channels.php`
  - New channels: `order.{userId}`, `admin.orders`

### 2. Frontend Changes (Flutter)

**New Files:**
- `bumdes_frontend/lib/src/services/order_sync_service.dart` - Polling service
- `bumdes_frontend/lib/src/config/app_config.dart` - Config dengan environment settings

**Modified Files:**
- `bumdes_frontend/lib/src/screens/order_history_screen.dart`
  - Integration dengan OrderSyncService
  - Auto-refresh on status changes

- `bumdes_frontend/lib/src/screens/home_screen.dart`
  - "Contoh data" badge conditional display

---

## How to Test

### Test 1: Order Cancellation Works
```
1. Login sebagai pembeli
2. Buat pesanan baru
3. Klik "Batalkan Pesanan"
4. Verifikasi:
   ✅ Status berubah ke "Dibatalkan"
   ✅ Stok produk dikembalikan
   ✅ Payment status = "CANCELLED"
```

### Test 2: Sync Across Dashboards
```
1. Buka 2 devices/browser:
   - Device A: Dashboard Pembeli
   - Device B: Dashboard Penjual

2. Di Device A: Batalkan pesanan

3. Verifikasi:
   ✅ Device A: Status update langsung
   ✅ Device B: Status update dalam ~30 detik
   ✅ Snackbar notification muncul
```

### Test 3: UI is Clean (Production Mode)
```
1. Build: flutter build apk --release
2. Install on device
3. Verifikasi:
   ✅ "Contoh data" badge TIDAK ada
   ✅ Dashboard tampil clean
   ✅ No placeholder text visible
```

### Test 4: API Endpoints
```
Gunakan Postman/Insomnia:

GET /api/orders/buyer/sync
Headers: Authorization: Bearer {token}
Params: last_sync=2026-01-01%2012:00:00&limit=10

Expected Response:
{
  "message": "Riwayat pesanan pembeli (sync)",
  "data": [...orders...],
  "pagination": {...},
  "sync_timestamp": "2026-01-01 12:00:00"
}
```

---

## Configuration

### Backend Broadcasting Driver

**Current:** Set to 'null' (polling only)

**If you want real WebSocket:**
1. Edit `bumdes_jabar/laravel/.env`:
   ```
   BROADCAST_DRIVER=pusher
   PUSHER_APP_ID=your-app-id
   PUSHER_APP_KEY=your-app-key
   PUSHER_APP_SECRET=your-app-secret
   PUSHER_APP_CLUSTER=mt1
   ```

2. Or use Redis:
   ```
   BROADCAST_DRIVER=redis
   REDIS_HOST=127.0.0.1
   REDIS_PASSWORD=null
   REDIS_PORT=6379
   ```

### Frontend Configuration

Edit `bumdes_frontend/lib/src/config/app_config.dart`:

```dart
// Change polling interval
static const Duration orderSyncInterval = Duration(seconds: 30);

// Toggle feature flags
static bool get enableRealTimeSync => true;
static bool get showSampleDataBadge => isDevelopment; // Only dev
```

---

## Monitoring & Troubleshooting

### Monitor Polling
1. Flutter: Check console logs
   ```
   Look for: "OrderSyncService error" or sync messages
   ```

2. Laravel: Check storage/logs/laravel.log
   ```
   Look for: Event dispatches and API calls
   ```

### If Sync Not Working
```
1. Check API endpoint:
   GET /api/orders/buyer/sync
   
2. Check token is valid (auth)

3. Check polling interval hasn't elapsed
   (Default: 30 seconds)

4. Check Firebase or backend logs for errors

5. Manual refresh: Pull-to-refresh still works
```

### If Status Not Changing
```
1. Verify order has status "Menunggu Pembayaran"
2. Check database directly:
   SELECT * FROM orders WHERE id = ?
3. Verify API response includes updated_at
4. Check polling service is running
```

---

## Performance Expectations

| Metric | Value | Notes |
|--------|-------|-------|
| Polling Interval | 30 seconds | Configurable |
| API Response Time | < 500ms | Should be fast |
| Memory Usage | < 50MB | Per order service |
| CPU Impact | Minimal | Jitter prevents spikes |
| Data Transfer | ~ 5-10KB per poll | Filtered by last_sync |

---

## Deployment Steps

### 1. Backend
```bash
# No migrations needed - using existing schema
php artisan cache:clear
php artisan config:cache
# Restart app if using queue
```

### 2. Frontend
```bash
flutter pub get
flutter build apk --release
# OR
flutter build ios --release
```

### 3. Verify
```bash
# Test order cancellation
curl -X PUT http://localhost:8000/api/orders/{id}/cancel \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json"

# Test sync endpoint
curl http://localhost:8000/api/orders/buyer/sync \
  -H "Authorization: Bearer {token}"
```

---

## Rollback Plan

If something breaks:

**Backend:**
```bash
git log --oneline | head -10
git revert [commit-hash]
php artisan cache:clear
```

**Frontend:**
```bash
git log --oneline | head -10
git revert [commit-hash]
flutter pub get
flutter build apk --release
```

---

## Documentation Files

For more details, see:
- `ORDER_CANCELLATION_AND_SYNC_IMPLEMENTATION.md` - Full technical docs
- `ORDER_CANCELLATION_SYNC_SUMMARY.md` - Implementation summary
- `IMPLEMENTATION_VERIFICATION_CHECKLIST.md` - QA checklist

---

## Support

### FAQ

**Q: Bagaimana user tahu pesanan sudah dibatalkan?**
A: 
- Snackbar notification di app
- Status berubah di dashboard
- N8n notification (WhatsApp/Telegram)

**Q: Apakah data sync real-time?**
A: Quasi real-time (polling setiap 30 detik). Untuk true real-time, gunakan WebSocket.

**Q: Apa yang terjadi jika API down?**
A: Polling akan retry. User masih bisa manual refresh dengan pull-to-refresh.

**Q: Bagaimana jika network lambat?**
A: Jitter mechanism mencegah server overload. Polling akan tetap berjalan.

---

## Status

✅ **READY FOR DEPLOYMENT**

- Backend implementation: COMPLETE
- Frontend implementation: COMPLETE
- Testing checklist: PREPARED
- Documentation: COMPLETE

---

**Last Updated:** 2026-01-06
**Version:** 1.0.0
