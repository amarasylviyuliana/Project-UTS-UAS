# Product Flow Diagram - After Fixes

## SELLER ADDS PRODUCT (Product Persistence Fixed)

```
┌─────────────────────────────────────────────────────────────────┐
│                    SELLER ADDS PRODUCT FLOW                      │
└─────────────────────────────────────────────────────────────────┘

FLUTTER APP (Frontend)          LARAVEL API (Backend)           DATABASE
───────────────────────         ─────────────────────           ────────

    ProductFormScreen
         │
         │ User fills:
         │ - Name: "Sayuran Organik"
         │ - Category: "Pertanian" (ID: 1)
         │ - Price: 50000
         │ - Stock: 100
         │
         ├─→ [Click "Simpan"]
         │
         │ ProductProvider.createProductOnServer()
         │   │
         │   ├─→ ProductService.createProduct()
         │
         │ POST /api/products ───────────────────→ ProductController.store()
         │                                           │
         │                                           ├─→ Validate request
         │                                           │
         │                                           ├─→ Check user role
         │                                           │   (must be "Penjual")
         │                                           │
         │                                           ├─→ Check store exists
         │                                           │
         │                                           ├─→ Create in DB:
         │ ◄──────────────────────────────────────   │   INSERT INTO products
         │   {                                       │   - name: "Sayuran Organik"
         │     "id": 10,                            │   - store_id: 1
         │     "name": "Sayuran Organik",           │   - price: 50000
         │     "store_name": "BUMDes Ciwidey",      │   - stock: 100
         │     "category": "Pertanian",             │   - category_id: 1
         │     ...                                  │
         │   }                                       │
         │                                           ├─→ Return 201 with data
         │
         ├─→ ProductProvider.addProduct()
         │   (update local _products list)
         │
         ├─→ Show SnackBar: "Produk berhasil ditambahkan"
         │
         └─→ Navigate back to Katalog tab
            (product now visible in seller's list)


🔄 PERSISTENCE CHECK: Close & Reopen App
─────────────────────────────────────────
         │
         └─→ ProductProvider._loadProducts()
             │
             └─→ ProductService.fetchProducts()
                 │
                 └─→ GET /api/products ────────→ ProductController.index()
                                                  │
                                                  └─→ SELECT * FROM products
                                                      WHERE is_active = true
                                                      
                     ◄─────────────────────────────────
                      "Sayuran Organik" still there! ✅
```

---

## BUYER SEES PRODUCT (Cross-App Visibility Fixed)

```
┌──────────────────────────────────────────────────────┐
│      BUYER VIEWS PRODUCTS (After Seller Creates)     │
└──────────────────────────────────────────────────────┘

BUYER'S APP                  LARAVEL API                DATABASE
──────────────              ─────────────              ────────

  HomeScreen
     │
     └─→ ProductProvider
         │
         └─→ ProductService.fetchProducts()
             │
             └─→ GET /api/products ──────────→ ProductController.index()
                                               │
                                               └─→ SELECT * FROM products
                                                   + relationships
                                                   
                     ◄──────────────────────────
                     [
                       {id: 1, name: "Beras"},
                       {id: 2, name: "Kerupuk"},
                       ...
                       {id: 10, "Sayuran Organik"},  ← Seller's new product!
                     ]
             
             ├─→ Parse to ProductModel list
             │
             └─→ Display in GridView
                 - "Sayuran Organik" card appears ✅
                 - Buyer can tap to view details
                 - Buyer can add to cart & checkout
```

---

## SELLER VIEWS ORDERS (Dashboard Orders Fixed)

```
┌─────────────────────────────────────────────────────┐
│       SELLER VIEWS DASHBOARD ORDERS (Real Data)    │
└─────────────────────────────────────────────────────┘

SELLER'S APP                LARAVEL API              DATABASE
───────────────            ─────────────            ────────

  StoreDashboardScreen
         │
         ├─→ Click "Pesanan" tab
         │
         ├─→ _loadSellerOrders()
         │
         └─→ OrderService.getSellerOrders(token)
             │
             └─→ GET /api/seller/orders ────→ OrderController@getSellerOrders
                                              │
                                              └─→ SELECT * FROM orders
                                                  WHERE store_id = current_seller
                                                  
                     ◄──────────────────────────
                     [
                       {
                         "id": 1,
                         "status": "Menunggu Konfirmasi",
                         "total": 150000,
                         "createdAt": "2024-05-25"
                       },
                       ...
                     ]
             
             ├─→ setState({ _sellerOrders = orders })
             │
             ├─→ Display order counts:
             │   - Menunggu Konfirmasi: 2
             │   - Dalam Pengiriman: 1
             │   - Selesai: 5
             │
             └─→ Show order history list
                 (no more hardcoded INV-00123 data!) ✅
```

---

## KEY IMPROVEMENTS

### Before (Non-Functional)
```
❌ Seller adds product → stored in app memory only
❌ App restart → product lost
❌ Buyer never sees seller's products
❌ Dashboard shows mock orders: INV-00123, INV-00124, etc.
❌ Profile options show "fitur sedang dikembangkan" messages
```

### After (Fully Functional)
```
✅ Seller adds product → calls POST /api/products
✅ Backend validates & creates in database
✅ App immediately updates UI with backend response
✅ App restart → fetches from API, product still there
✅ Buyer sees real products added by sellers
✅ Dashboard orders tab fetches real data: GET /api/seller/orders
✅ Profile options have proper handlers
✅ All data flows through API, persists to database
```

---

## Error Handling

```
USER ACTION                    APP BEHAVIOR
───────────────              ────────────────────────

Add product                 → Loader shows
  ↓
API call success            → Show "Produk berhasil ditambahkan"
                             → Add to UI list
                             → Navigate back
  ↓
API call fails              → Show error: "Gagal menyimpan produk: [error]"
                             → Product NOT added to UI
                             → Stay on form (can retry)


View seller orders          → Loader shows "Loading..."
  ↓
API returns orders          → Display real order list
                             → Show order counts by status
  ↓
API fails/no orders         → Show "Belum ada pesanan"
                             → Or error message if network issue
```

---

## Technology Stack Integration

```
Frontend Request Path:
─────────────────────
Flutter App → AuthProvider (token) → ApiService → Http Client
                                    ↓
                              POST /api/products
                              GET /api/seller/orders


Backend Processing:
──────────────────
Route Middleware:
  1. Sanctum (verify token)
  2. Auth (authenticate user)
  3. Verify role = "Penjual"

Controller:
  1. Validate input
  2. Check store exists
  3. Query/create database
  4. Load relationships
  5. Format response

Response:
  ↓
Frontend Provider updates state
  ↓
UI rebuilds with new data
  ↓
User sees changes
```

---

## Testing Checklist

- [ ] Seller adds "Sayuran Organik" product (50000 IDR)
  - [ ] Success message appears
  - [ ] Close app completely
  - [ ] Reopen → Product still in seller's catalog ✅

- [ ] Buyer searches/browses products
  - [ ] "Sayuran Organik" appears in list ✅
  - [ ] Buyer can tap and view details ✅
  - [ ] Buyer can add to cart ✅

- [ ] Seller views Pesanan (Orders) tab
  - [ ] Real orders display (or "Belum ada pesanan" if empty) ✅
  - [ ] Order counts match database ✅
  - [ ] No mock data (INV-00123) ✅

- [ ] Seller clicks profile options
  - [ ] Each option shows feedback message ✅
  - [ ] No crashes or "fitur sedang dikembangkan" ✅

---

**Architecture**: Clean separation of Frontend (Flutter) ↔ API (Laravel) ↔ Database (MySQL)  
**Data Flow**: User Action → Frontend → Backend Validation → Database → Response → UI Update  
**Persistence**: All data changes saved to database immediately (not local-only)
