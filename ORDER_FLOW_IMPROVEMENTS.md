# 🔧 Order Flow Implementation Improvements

## Status: Ready to Implement

Dokumentasi ini berisi list improvements untuk membuat order flow lebih lengkap dan sempurna tanpa errors.

---

## 🐛 Issues Found & Fixes

### 1. Status Transition Logic Error (CRITICAL)
**File:** `bumdes_frontend/lib/src/screens/order_detail_screen.dart`
**Line:** ~539
**Issue:** Logic condition `if (order.status.toLowerCase() == 'dikonfirmasi' && order.status.toLowerCase() != 'diproses')` akan selalu true karena kondisi tidak bisa simultaneous.

**Current Code:**
```dart
if (order.status.toLowerCase() == 'dikonfirmasi' && order.status.toLowerCase() != 'diproses')
  // Show "Pesanan Sedang Disiapkan" button
```

**Fix:**
```dart
if (order.status.toLowerCase() == 'dikonfirmasi')
  // Show "Pesanan Sedang Disiapkan" button
  
// Atau lebih baik:
if (order.status.toLowerCase().contains('dikonfirmasi') && 
    !order.status.toLowerCase().contains('diproses'))
  // Show button
```

---

### 2. Payment Proof Upload Missing
**Status:** Need Implementation
**Priority:** HIGH

**Current Flow:** 
- Buyer checkout → Payment Gateway (Xendit) → Done
- No UI for manual payment proof upload

**Needed:** 
- UI screen untuk upload bukti pembayaran (untuk yang prefer bank transfer manual)
- Logic untuk accept proof dan notify seller
- Seller can see proof dan confirm/reject

**Implementation Steps:**
1. Create `payment_proof_screen.dart`
2. Add upload image functionality with validation
3. Add endpoint call to `POST /api/payments/{orderId}/upload-proof`
4. Update order status to "Menunggu Konfirmasi"
5. Add payment proof view di seller orders screen

---

### 3. Seller Payment Confirmation UI Missing
**Status:** Need Implementation
**Priority:** HIGH

**Current Flow:**
- Buyer uploads payment proof → Order status: Menunggu Konfirmasi
- Seller can't see proof and confirm/reject from Flutter app

**Needed:**
- UI untuk seller melihat payment proof
- Button "Confirm Payment" dan "Reject Payment"
- Integration dengan `/api/payments/{orderId}/confirm` dan `/api/payments/{orderId}/reject`

**Implementation:**
```dart
// Di order_detail_screen.dart, untuk Seller role:
if (order.status == 'Menunggu Konfirmasi')
  // Show payment proof image
  // Show "Confirm Payment" dan "Reject Payment" buttons
```

---

### 4. Admin Dashboard Reports Missing
**Status:** Need Implementation
**Priority:** MEDIUM

**Current State:**
- Backend sudah punya `/api/reports/platform` endpoint
- Frontend TIDAK ada admin dashboard screen

**Needed:**
- Create `admin_dashboard_screen.dart`
- Display platform statistics:
  - Total Users (Buyers + Sellers)
  - Total Stores
  - Total Products
  - Total Orders (by status breakdown)
  - Total Revenue
  - Top Sellers
  - Daily/Monthly Breakdown
- Date range filter

---

### 5. Payment Status Sync Issue
**Status:** Need Verification & Fix
**Issue:** Order status bisa out of sync dengan payment status

**Current Problem:**
- Payment dapat pending/confirmed tapi order status berbeda
- Xendit webhook update payment tapi mungkin tidak selalu update order

**Fix Needed:**
```php
// Di PaymentController.php webhook():
// Ensure order status always matches payment status

if ($status === 'PAID') {
    $order->status = 'Dikonfirmasi';  // AUTO-confirm if Xendit already paid
    $order->save();
}
```

---

### 6. Order Cancellation Only Allowed in "Menunggu Pembayaran"
**Status:** Implemented ✓
**Verification:** Check that stock is restored when cancelled ✓

**Current:** OK
**Code Location:** `OrderController.php` - `cancelOrder()` method

---

### 7. Seller Can't Update to "Diproses" Status
**Status:** ISSUE FOUND
**Problem:** No UI button untuk seller update dari "Dikonfirmasi" ke "Diproses"

**Current UI Show:**
- Dikonfirmasi → Can show "Pesanan Sedang Disiapkan" OR "Kirim Pesanan"
- Problem: Logic unclear, both buttons might show

**Fix:**
```dart
// Clear state transitions:
// Dikonfirmasi → [Can do "Pesanan Sedang Disiapkan" (→ Diproses)] OR ["Kirim Pesanan" (→ Dikirim)]

if (order.status.toLowerCase() == 'dikonfirmasi') {
  // Button 1: "Pesanan Sedang Disiapkan" → Updates to "Diproses"
  // Button 2: "Kirim Pesanan" → Updates to "Dikirim"
}

if (order.status.toLowerCase() == 'diproses') {
  // Button: "Kirim Pesanan" → Updates to "Dikirim"
}
```

---

### 8. Missing Order Status Enum/Constant
**Status:** Need Implementation
**File:** `bumdes_frontend/lib/src/utils/` or `bumdes_frontend/lib/src/constants/`

**Create:**
```dart
// order_status.dart
class OrderStatus {
  static const String WAITING_PAYMENT = 'Menunggu Pembayaran';
  static const String WAITING_CONFIRMATION = 'Menunggu Konfirmasi';
  static const String CONFIRMED = 'Dikonfirmasi';
  static const String PROCESSING = 'Diproses';
  static const String SHIPPED = 'Dikirim';
  static const String COMPLETED = 'Selesai';
  static const String CANCELLED = 'Dibatalkan';

  static List<String> allStatuses = [
    WAITING_PAYMENT,
    WAITING_CONFIRMATION,
    CONFIRMED,
    PROCESSING,
    SHIPPED,
    COMPLETED,
    CANCELLED,
  ];

  static Map<String, String> statusLabels = {
    WAITING_PAYMENT: 'Menunggu Pembayaran',
    WAITING_CONFIRMATION: 'Menunggu Konfirmasi Penjual',
    CONFIRMED: 'Telah Dikonfirmasi',
    PROCESSING: 'Sedang Disiapkan',
    SHIPPED: 'Sedang Dikirim',
    COMPLETED: 'Selesai',
    CANCELLED: 'Dibatalkan',
  };

  static List<String> getValidNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case WAITING_PAYMENT:
        return [WAITING_CONFIRMATION, CANCELLED];
      case WAITING_CONFIRMATION:
        return [CONFIRMED];
      case CONFIRMED:
        return [PROCESSING, SHIPPED];
      case PROCESSING:
        return [SHIPPED];
      case SHIPPED:
        return [COMPLETED];
      default:
        return [];
    }
  }
}
```

---

## ✅ Implementation Plan (Prioritized)

### Phase 1: Critical Fixes (Do First)
- [ ] Fix status transition logic in order_detail_screen.dart (Line 539)
- [ ] Add PaymentProofScreen for manual payment upload
- [ ] Add seller payment confirmation UI di order_detail_screen
- [ ] Verify and fix payment status sync di webhook
- [ ] Create OrderStatus constants

**Estimated Time:** 2-3 hours

### Phase 2: UI/UX Improvements (Do Second)
- [ ] Create admin dashboard screen untuk reports
- [ ] Improve order status transitions (clearer buttons)
- [ ] Add date filter untuk orders
- [ ] Add search functionality untuk orders

**Estimated Time:** 2-3 hours

### Phase 3: Testing & Polish (Do Third)
- [ ] Test complete buyer flow: checkout → payment → completion
- [ ] Test complete seller flow: receive order → confirm → process → ship
- [ ] Test admin reports
- [ ] Test error scenarios
- [ ] Performance optimization

**Estimated Time:** 2-3 hours

---

## 📝 Testing Scenarios

### Buyer Side
```
1. Checkout
   - Add product to cart
   - Proceed to checkout
   - Fill delivery info
   - Create order ✓
   
2. Payment
   - Via Xendit gateway ✓
   - Or upload payment proof (NEW)
   
3. Track Order
   - See order status updates
   - Get notifications
   
4. Confirm Receipt
   - When order shipped
   - Mark as complete ✓
```

### Seller Side
```
1. Receive Order
   - See incoming orders
   - If payment proof: review dan confirm/reject
   - If Xendit: auto-confirm
   
2. Process Order
   - Confirm payment (if needed)
   - Update to "Diproses"
   - Update to "Dikirim"
   
3. View Reports
   - See store statistics
   - Filter by date
   - See revenue
```

### Admin Side
```
1. View Dashboard
   - Total stats
   - Top sellers
   - Revenue breakdown
   - Filter by date
```

---

## 🔗 API Endpoints Used

```
POST   /api/checkout                      - Create order
GET    /api/orders/buyer/history          - Get buyer orders
GET    /api/orders/{id}                   - Get order detail
PUT    /api/orders/{id}/confirm-receipt   - Confirm receipt (buyer)
PUT    /api/orders/{id}/cancel            - Cancel order (buyer)

GET    /api/seller/orders                 - Get seller orders
PUT    /api/orders/{id}/status            - Update order status (seller)

POST   /api/payments/{orderId}/upload-proof    - Upload proof (NEW)
GET    /api/payments/{orderId}/proof          - Get proof (NEW)
POST   /api/payments/{orderId}/confirm        - Confirm payment (seller)
POST   /api/payments/{orderId}/reject         - Reject payment (seller)

GET    /api/reports/buyer                 - Buyer report
GET    /api/reports/store                 - Store report
GET    /api/reports/platform              - Platform report (admin)
```

---

## 📦 Files Need to Create/Modify

### Create New Files
1. `bumdes_frontend/lib/src/screens/payment_proof_screen.dart` - NEW
2. `bumdes_frontend/lib/src/screens/admin_dashboard_screen.dart` - Enhancement
3. `bumdes_frontend/lib/src/constants/order_status.dart` - NEW
4. `bumdes_frontend/lib/src/widgets/payment_proof_widget.dart` - NEW (reusable)

### Modify Existing Files
1. `bumdes_frontend/lib/src/screens/order_detail_screen.dart` - Fix logic + add payment proof UI
2. `bumdes_frontend/lib/src/services/order_service.dart` - Add payment proof methods
3. `bumdes_frontend/lib/src/app.dart` - Register new routes
4. `bumdes_jabar/laravel/app/Http/Controllers/PaymentController.php` - Verify webhook logic

---

## 🎯 Success Criteria

- [ ] Buyer can complete order flow without errors
- [ ] Seller receives orders dan can process them smoothly
- [ ] Payment confirmation works (both Xendit and manual proof)
- [ ] Order status updates correctly dan is synced across buyer/seller
- [ ] Admin can view complete platform reports
- [ ] No race conditions atau data inconsistencies
- [ ] Error messages are clear dan helpful
- [ ] All edge cases handled (cancelled, rejected, etc)

---

**Document Version:** 1.0
**Last Updated:** 2026-06-08
**Next Review:** After implementation
