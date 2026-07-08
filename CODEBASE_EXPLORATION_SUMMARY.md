# BUMDes Jabar Codebase Exploration - Key Areas Summary

## 1. ORDER CANCELLATION (Pembatalan Pesanan)

### Backend Implementation

**Main Controller:**
- [bumdes_jabar/laravel/app/Http/Controllers/OrderController.php](bumdes_jabar/laravel/app/Http/Controllers/OrderController.php#L403-L435)

**Cancel Order Logic (Lines 403-435):**
```php
/**
 * Buyer cancels order
 * Business rule: Buyer can cancel order if status is 'Menunggu Pembayaran'
 */
public function cancelOrder(Request $request, $id): JsonResponse
{
    $order = Order::with('orderItems.product')->find($id);

    if (!$order || $order->buyer_id !== $request->user()->id) {
        return response()->json([
            'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
        ], 404);
    }

    if ($order->status !== 'Menunggu Pembayaran') {
        return response()->json([
            'message' => 'Pesanan tidak dapat dibatalkan karena status sudah berubah',
        ], 422);
    }

    DB::transaction(function () use ($order) {
        foreach ($order->orderItems as $item) {
            if ($item->product->type === 'produk') {
                $item->product->increment('stock', $item->quantity);  // Restore stock
            }
        }

        $order->update(['status' => 'Dibatalkan']);

        // Cancel any active payment process
        if ($order->payment) {
            $order->payment->update([
                'status' => 'Cancelled',
                'payment_status' => 'CANCELLED',
            ]);
        }
    });

    return response()->json([
        'message' => 'Pesanan berhasil dibatalkan',
        'data' => $order,
    ]);
}
```

**Key Business Rules:**
- ✅ Only buyer can cancel their own order
- ✅ Cancellation only allowed when status = 'Menunggu Pembayaran' (Awaiting Payment)
- ✅ Stock is restored for physical products (type = 'produk')
- ✅ Payment record is cancelled to prevent processing
- ✅ Database transaction ensures atomicity

**API Endpoint:**
- `PUT /api/orders/{id}/cancel` → [routes/api.php](bumdes_jabar/laravel/routes/api.php#L133)

---

### Frontend Implementation

**Cancel Service:**
- [bumdes_frontend/lib/src/services/order_service.dart](bumdes_frontend/lib/src/services/order_service.dart#L114-L118)

```dart
Future<Map<String, dynamic>> cancelOrder(String token, int orderId) async {
    final api = ApiService(token: token);
    return await api.put('/orders/$orderId/cancel', {});
}
```

**UI Implementation:**
- [bumdes_frontend/lib/src/screens/order_detail_screen.dart](bumdes_frontend/lib/src/screens/order_detail_screen.dart#L206-L230)

```dart
Future<void> _cancelOrder() async {
    // Shows confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        // ... action buttons
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isPerformingAction = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final orderService = OrderService();
      await orderService.cancelOrder(auth.token!, _order!.id);
      // ... success feedback
      await _refreshOrder();  // Refresh UI
    } catch (e) {
      // ... error handling
    }
}
```

**Status Check for Display:**
- Line 566 in order_detail_screen.dart shows cancel button logic:
  - Only displays if `order.status == 'Menunggu Pembayaran'`
  - Placed in a conditional: `// Tombol Batalkan untuk Pembeli`

---

## 2. ORDER STATUS MANAGEMENT

### Status Definition

**Centralized Constants:**
- [bumdes_frontend/lib/src/constants/order_status.dart](bumdes_frontend/lib/src/constants/order_status.dart)

**All Order Statuses:**
```dart
static const String waitingPayment = 'Menunggu Pembayaran';
static const String waitingConfirmation = 'Menunggu Konfirmasi';
static const String confirmed = 'Dikonfirmasi';
static const String processing = 'Diproses';
static const String packed = 'Dikemas';
static const String shipped = 'Dikirim';
static const String estimatedArrival = 'Estimasi Sampai';
static const String completed = 'Selesai';
static const String cancelled = 'Dibatalkan';

static const List<String> allStatuses = [
    waitingPayment,
    waitingConfirmation,
    confirmed,
    processing,
    packed,
    shipped,
    estimatedArrival,
    completed,
    cancelled,
];
```

**Role-Specific Labels:**
```dart
// Buyer-facing labels
static final Map<String, String> buyerLabels = {
    waitingPayment: 'Menunggu Pembayaran',
    waitingConfirmation: 'Menunggu Konfirmasi Penjual',
    confirmed: 'Pesanan Dikonfirmasi',
    processing: 'Sedang Disiapkan',
    packed: 'Pesanan Dikemas',
    shipped: 'Sedang Dikirim',
    estimatedArrival: 'Estimasi Sampai',
    completed: 'Pesanan Selesai ✓',
    cancelled: 'Dibatalkan',
};

// Seller-facing labels (different wording)
static final Map<String, String> sellerLabels = {
    waitingPayment: 'Menunggu Pembayaran dari Pembeli',
    waitingConfirmation: 'Menunggu Konfirmasi Pembayaran',
    confirmed: 'Pembayaran Dikonfirmasi - Siap Dikirim',
    // ... more labels
};
```

---

### Status Update Flow

**Backend - Seller/Admin Update:**
- [bumdes_jabar/laravel/app/Http/Controllers/OrderController.php](bumdes_jabar/laravel/app/Http/Controllers/OrderController.php#L328-L370)

```php
/**
 * Update order status
 * REQ-24
 */
public function updateStatus(Request $request, $id): JsonResponse
{
    $user = $request->user();

    if (! $user->isSeller() && ! $user->isAdmin()) {
        return response()->json([
            'message' => 'Hanya penjual atau admin yang dapat mengubah status pesanan',
        ], 403);
    }

    $order = Order::find($id);

    if (!$order || $order->store->user_id !== $user->id) {
        return response()->json([
            'message' => 'Pesanan tidak ditemukan atau anda tidak punya akses',
        ], 404);
    }

    $validated = $request->validate([
        'status' => 'required|in:Menunggu Pembayaran,Menunggu Konfirmasi,Dikonfirmasi,Diproses,Dikemas,Dikirim,Estimasi Sampai,Selesai,Dibatalkan',
    ]);

    // Set delivery/completion timestamps
    if ($validated['status'] === 'Dikirim') {
        $order->delivered_at = now();
    } elseif ($validated['status'] === 'Selesai') {
        $order->completed_at = now();
    }

    $order->status = $validated['status'];
    $order->save();

    // Credit wallet when order completed
    if ($validated['status'] === 'Selesai') {
        app(\App\Services\WalletService::class)->creditFromCompletedOrder($order);
    }

    return response()->json([
        'message' => 'Status pesanan diperbarui',
        'data' => $order,
    ]);
}
```

**API Endpoints:**
- `PUT /api/orders/{id}/status` → [Seller/Admin update](bumdes_jabar/laravel/routes/api.php#L131)
- `PUT /admin/orders/{id}/status` → [Admin-specific update](bumdes_jabar/laravel/routes/api.php#L198)

**Frontend - Status Update:**
- [bumdes_frontend/lib/src/services/order_service.dart](bumdes_frontend/lib/src/services/order_service.dart#L99-L103)

```dart
Future<Map<String, dynamic>> updateOrderStatus(
    String token,
    int orderId,
    String status,
) async {
    final api = ApiService(token: token);
    final payload = {'status': status};
    return await api.put('/orders/$orderId/status', payload);
}
```

- [bumdes_frontend/lib/src/screens/order_detail_screen.dart](bumdes_frontend/lib/src/screens/order_detail_screen.dart#L135-L157)

```dart
Future<void> _updateOrderStatus(String status) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null || _order == null) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
      _refreshError = null;
    });

    try {
      await OrderService().updateOrderStatus(auth.token!, _order!.id, status);
      await _refreshOrder();  // Refresh to get updated data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status pesanan diperbarui ke "$status".')),
        );
      }
    } catch (e) {
      // ... error handling
    }
}
```

---

## 3. BUYER DASHBOARD STRUCTURE

### Main Entry Point

**Home Screen (Buyer Dashboard):**
- [bumdes_frontend/lib/src/screens/home_screen.dart](bumdes_frontend/lib/src/screens/home_screen.dart)

**Dashboard Navigation (Lines 30-90):**
```dart
final pages = <Widget>[
    const HomeTab(),              // Tab 1: Browse products
    const SearchTab(),            // Tab 2: Search
    const CartScreen(),           // Tab 3: Shopping cart
    const OrderHistoryScreen(),   // Tab 4: ORDER HISTORY ← Main buyer dashboard
    const ProfileScreen(),        // Tab 5: Profile
];

final menuLabels = [
    'Beranda',
    'Pencarian',
    'Keranjang',
    'Pesanan',    // ← Buyer's order tracking
    'Profil',
];
```

**Role-Based Routing:**
```dart
if (role == 'seller') {
    Navigator.pushReplacementNamed(context, '/store-dashboard');  // → Seller dashboard
}
if (role == 'admin') {
    Navigator.pushReplacementNamed(context, '/admin-dashboard');  // → Admin dashboard
}
// Buyer stays on HomeScreen (role == 'pembeli')
```

---

### Order History Screen (Buyer's Order Tracking)

**File:**
- [bumdes_frontend/lib/src/screens/order_history_screen.dart](bumdes_frontend/lib/src/screens/order_history_screen.dart)

**Features:**
- **Tabbed View** with status filters (Lines 27-40):
  ```dart
  final List<String> _tabLabels = [
      'Semua',                 // All orders
      'Menunggu Bayar',        // Awaiting payment
      'Dikonfirmasi',          // Confirmed
      'Diproses',              // Processing
      'Dikirim',               // Shipped
      'Selesai',               // Completed
      'Dibatalkan',            // Cancelled
  ];
  ```

- **Pull-to-Refresh** (Line 168):
  ```dart
  return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(...),
  );
  ```

- **Order List Card Display** (Line 195-250):
  - Shows order ID, status, recipient name, total price
  - Color-coded status indicators
  - Tap to view order detail

**Load Orders:**
```dart
void _loadOrders() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.token != null) {
        _ordersFuture = OrderService().fetchOrders(auth.token!);
    }
}
```

---

### Backend - Get Buyer Orders

[bumdes_jabar/laravel/app/Http/Controllers/OrderController.php](bumdes_jabar/laravel/app/Http/Controllers/OrderController.php#L278-L293)

```php
/**
 * Get buyer's order history
 * REQ-31
 */
public function getBuyerOrders(Request $request): JsonResponse
{
    $orders = $request->user()->orders()
        ->with(['store', 'payment', 'orderItems.product'])
        ->latest()
        ->paginate(10);

    return response()->json([
        'message' => 'Riwayat pesanan pembeli',
        'data' => $orders,
    ]);
}
```

**API Endpoint:**
- `GET /api/orders/buyer/history?page=1` → [routes/api.php](bumdes_jabar/laravel/routes/api.php#L128)

---

## 4. REAL-TIME SYNC MECHANISM

### Current Implementation: Polling-Based Refresh

**No Active WebSocket/Broadcasting Currently Implemented**

The application uses a **manual refresh pattern** rather than true real-time push updates:

**Architecture:**
```
┌─────────────────────────────────────────────┐
│           Frontend (Flutter)                │
├─────────────────────────────────────────────┤
│                                             │
│  OrderHistoryScreen / OrderDetailScreen    │
│         ↓                                   │
│  User pulls to refresh / Manual button     │
│         ↓                                   │
│  OrderService.fetchOrders()               │
│  OrderService.getOrder(orderId)           │
│         ↓                                   │
└─────────────────────────────────────────────┘
           HTTP GET Request
           ↓
┌─────────────────────────────────────────────┐
│         Backend (Laravel API)               │
├─────────────────────────────────────────────┤
│                                             │
│  OrderController@getBuyerOrders            │
│  OrderController@getSellerOrders           │
│  OrderController@show                      │
│         ↓                                   │
│  Query database for current state         │
│         ↓                                   │
│  JSON Response with updated data          │
│                                             │
└─────────────────────────────────────────────┘
```

---

### Manual Refresh Points

**1. Order History Screen - Pull-to-Refresh:**
- [bumdes_frontend/lib/src/screens/order_history_screen.dart](bumdes_frontend/lib/src/screens/order_history_screen.dart#L75-L80)
```dart
Future<void> _refreshOrders() async {
    _loadOrders();
    setState(() {});
    await _ordersFuture;
}
```

**2. Order Detail Screen - Manual Refresh:**
- [bumdes_frontend/lib/src/screens/order_detail_screen.dart](bumdes_frontend/lib/src/screens/order_detail_screen.dart#L80-L130)

```dart
Future<void> _refreshOrder() async {
    if (!auth.isAuthenticated || auth.token == null || _order == null) {
        return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });

    try {
      final loadedOrder = await OrderService().getOrder(auth.token!, _order!.id);
      if (!mounted) return;
      setState(() => _order = loadedOrder);
    } catch (e) {
      setState(() => _refreshError = '...');
    } finally {
      setState(() => _isRefreshing = false);
    }
}
```

**3. Seller Orders Screen - Pull-to-Refresh:**
- [bumdes_frontend/lib/src/screens/seller_orders_screen.dart](bumdes_frontend/lib/src/screens/seller_orders_screen.dart#L76-L88)
```dart
Future<void> _load() async {
    setState(() {
        _loading = true;
        _errorMessage = null;
    });
    try {
        final res = await _service.getSellerOrders(token);
        if (mounted) {
            setState(() {
                _orders = res;
                _loading = false;
            });
        }
    } catch (e) {
        // ... error handling
    }
}
```

---

### Notification Service (N8n Integration)

**File:**
- [bumdes_jabar/laravel/app/Services/N8nNotificationService.php](bumdes_jabar/laravel/app/Services/N8nNotificationService.php)

**Notification Events:**

1. **When Order is Created:**
   - Triggered in: [OrderController.php](bumdes_jabar/laravel/app/Http/Controllers/OrderController.php#L200-L202)
   ```php
   $n8nNotifier = new N8nNotificationService();
   if (isset($createdOrder)) {
       $n8nNotifier->notifyNewOrder($createdOrder);
   }
   ```

2. **When Payment is Confirmed:**
   - Triggered in: [MidtransController.php](bumdes_jabar/laravel/app/Http/Controllers/MidtransController.php#L119)
   - Triggered in: [PaymentController.php](bumdes_jabar/laravel/app/Http/Controllers/PaymentController.php#L212)
   ```php
   if ($payment->status === 'Confirmed') {
       (new N8nNotificationService())->notifyPaymentConfirmed($order);
   }
   ```

**Notification Payload Example:**
```php
public function notifyNewOrder(Order $order): void
{
    $this->send([
        'event'        => 'order_created',
        'order_id'     => $order->id,
        'order_number' => $order->order_number,
        'bumdes_nama'  => $order->store->store_name ?? '-',
        'bumdes_wa'    => $order->store->contact_phone ?? '',
        'pembeli_nama' => $order->buyer->name ?? $order->recipient_name,
        'pembeli_wa'   => $order->buyer->phone ?? $order->recipient_phone ?? '',
        'pembeli_telegram_chat_id' => $order->buyer->telegram_chat_id ?? null,
        'item'         => $itemNames,
        'status'       => $order->status,
        'total'        => (float) $order->total_price,
    ]);
}
```

**Flow:**
- N8n receives webhook at `N8N_WEBHOOK_URL`
- N8n workflows can send notifications via:
  - WhatsApp (buyer & seller)
  - Telegram (buyer & seller)
  - Email
  - SMS
- Wrapped in try-catch so failures don't affect main order flow

---

### Broadcast Service (Configured but Not Used)

**File:**
- [bumdes_jabar/laravel/routes/channels.php](bumdes_jabar/laravel/routes/channels.php)

**Current Setup:**
```php
Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});
```

**Status:**
- ⚠️ Channel authorization configured
- ❌ No event broadcasting implemented
- ❌ No frontend listeners for real-time updates
- 📝 `.env` has `BROADCAST_DRIVER=log` (not configured for production)

---

### Data Sync Between Dashboards

**Admin Dashboard:**
- [bumdes_frontend/lib/src/screens/admin_dashboard_screen.dart](bumdes_frontend/lib/src/screens/admin_dashboard_screen.dart#L48-L90)

Loads data on init:
```dart
@override
void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
}

void _loadAll() {
    _loadStats();
    _loadOrders();
    _loadUsers();
    _loadProducts();
    _loadStores();
    _loadStoreApprovals();
}
```

Gets all orders via:
```dart
Future<void> _loadOrders() async {
    final token = _token;
    if (token == null) return;
    try {
        final data = await _adminService.getAdminOrders(token);
        if (mounted) setState(() => _orders = data);
    } catch (e) {
        // ... error handling
    }
}
```

**Seller Dashboard:**
- [bumdes_frontend/lib/src/screens/store_dashboard_screen.dart](bumdes_frontend/lib/src/screens/store_dashboard_screen.dart#L56-L100)

```dart
Future<void> _loadSellerOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loadingOrders = true);
    try {
        final orders = await orderService.getSellerOrders(auth.token!);
        if (mounted) {
            setState(() {
                _sellerOrders = orders;
                _loadingOrders = false;
            });
        }
    }
}
```

---

## 5. KEY FILES SUMMARY

### Backend (Laravel)

| File | Purpose | Key Methods |
|------|---------|-------------|
| [OrderController.php](bumdes_jabar/laravel/app/Http/Controllers/OrderController.php) | Order management | `createOrder()`, `cancelOrder()`, `updateStatus()`, `confirmReceipt()`, `getBuyerOrders()`, `getSellerOrders()` |
| [Admin/AdminController.php](bumdes_jabar/laravel/app/Http/Controllers/Admin/AdminController.php) | Admin operations | `getAllOrders()`, `updateOrderStatus()`, `getDashboardStats()` |
| [PaymentController.php](bumdes_jabar/laravel/app/Http/Controllers/PaymentController.php) | Payment handling | `uploadProof()`, `confirmPayment()`, `submitPayment()` |
| [MidtransController.php](bumdes_jabar/laravel/app/Http/Controllers/MidtransController.php) | Midtrans webhooks | `notification()` (payment status sync) |
| [Order Model](bumdes_jabar/laravel/app/Models/Order.php) | Order data | Relationships: `buyer()`, `store()`, `orderItems()`, `payment()` |
| [Payment Model](bumdes_jabar/laravel/app/Models/Payment.php) | Payment data | Relationship: `order()` |
| [N8nNotificationService.php](bumdes_jabar/laravel/app/Services/N8nNotificationService.php) | External notifications | `notifyNewOrder()`, `notifyPaymentConfirmed()` |
| [routes/api.php](bumdes_jabar/laravel/routes/api.php) | API routes | Order, payment, admin endpoints |

### Frontend (Flutter)

| File | Purpose | Key Methods |
|------|---------|-------------|
| [order_status.dart](bumdes_frontend/lib/src/constants/order_status.dart) | Status constants | Status definitions, buyer/seller labels |
| [order_service.dart](bumdes_frontend/lib/src/services/order_service.dart) | API calls | `createOrder()`, `cancelOrder()`, `updateOrderStatus()`, `fetchOrders()`, `getSellerOrders()` |
| [admin_service.dart](bumdes_frontend/lib/src/services/admin_service.dart) | Admin API | `getAdminOrders()`, `updateOrderStatus()` |
| [home_screen.dart](bumdes_frontend/lib/src/screens/home_screen.dart) | Buyer dashboard | Navigation hub for buyers |
| [order_history_screen.dart](bumdes_frontend/lib/src/screens/order_history_screen.dart) | Buyer order tracking | Order list with status tabs, pull-to-refresh |
| [order_detail_screen.dart](bumdes_frontend/lib/src/screens/order_detail_screen.dart) | Order details | `_updateOrderStatus()`, `_cancelOrder()`, `_confirmReceipt()`, `_refreshOrder()` |
| [seller_orders_screen.dart](bumdes_frontend/lib/src/screens/seller_orders_screen.dart) | Seller order list | Incoming orders for sellers |
| [store_dashboard_screen.dart](bumdes_frontend/lib/src/screens/store_dashboard_screen.dart) | Seller dashboard | Overview + quick access to orders |
| [admin_dashboard_screen.dart](bumdes_frontend/lib/src/screens/admin_dashboard_screen.dart) | Admin dashboard | All data overview + management |

---

## 6. STATUS FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ORDER LIFECYCLE                             │
└─────────────────────────────────────────────────────────────────────┘

Menunggu Pembayaran
    ↓
    ├─→ [BUYER CANCELS] → Dibatalkan ✓
    │
    └─→ [PAYMENT CONFIRMED] → Dikonfirmasi
           ↓
           └─→ [SELLER CONFIRMS] → Menunggu Konfirmasi
                   ↓
                   └─→ [SELLER PROCESSES] → Diproses
                           ↓
                           └─→ [SELLER PACKS] → Dikemas
                                   ↓
                                   └─→ [SELLER SHIPS] → Dikirim
                                           ↓
                                           └─→ [ESTIMATED ARRIVAL] → Estimasi Sampai
                                                   ↓
                                                   └─→ [BUYER CONFIRMS RECEIPT] → Selesai ✓
                                                           ↓
                                                           └─→ [WALLET CREDITED]

Status Update Permissions:
- Menunggu Pembayaran: Only Buyer can cancel
- Dikonfirmasi onwards: Only Seller (store owner) can update
- Any status: Admin can update (override)
- Selesai: Triggers wallet credit to seller
```

---

## 7. IMPORTANT CONSTRAINTS & NOTES

### Cancellation Rules
✅ **Only** status `'Menunggu Pembayaran'` can be cancelled by buyer
✅ Stock is automatically restored
✅ Payment record must be cancelled simultaneously
❌ No cancellation after payment confirmed

### Status Update Rules
✅ Seller can only update orders from their own store
✅ Admin can update any order
✅ Status validation: only allowed enum values accepted
✅ Timestamps set automatically: `delivered_at` (Dikirim), `completed_at` (Selesai)

### Real-Time Sync Gaps
⚠️ **No automatic push notifications** - polling only
⚠️ **No WebSocket connection** - manual refresh required
⚠️ **N8n notifications external** - for WhatsApp/Telegram only
✅ **Data eventually consistent** - eventually accurate after refresh

### Data Access Control
- Buyers see only their own orders
- Sellers see only their store's orders
- Admins see all orders
- Payment confirmation triggers N8n webhook (external notification)

---

## 8. RECOMMENDATIONS FOR ENHANCEMENT

1. **Add Real-Time Updates:**
   - Enable Laravel Broadcasting with Redis/Pusher
   - Implement WebSocket listeners in Flutter
   - Push notifications for order status changes

2. **Implement Polling Interval:**
   - Auto-refresh every 30 seconds when viewing order detail
   - Use `Timer.periodic()` in Flutter

3. **Database Improvements:**
   - Add index on `order.buyer_id` and `order.store_id`
   - Add status change audit log table

4. **Frontend Notifications:**
   - Add local push notifications on status changes
   - Toast/snackbar when data updates in real-time

5. **Payment Status Sync:**
   - Add immediate status check after payment submission
   - Verify Midtrans webhook delivery with retry logic
