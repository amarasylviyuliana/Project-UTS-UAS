# Dokumen Perancangan Sistem - BUMDes Jabar

*Marketplace Produk & Jasa Antar BUMDes di Jawa Barat*

**Use Case Diagram • Activity Diagram • Perancangan Database (ERD) • Class Diagram • Deployment Diagram • Sequence Diagram**

Disusun berdasarkan SRS v3.0 dan source code (Laravel 11 + Flutter)
Juni 2026


## Daftar Isi

1. [Pendahuluan](#1-pendahuluan)
2. [Use Case Diagram](#2-use-case-diagram)
3. [Activity Diagram](#3-activity-diagram)
4. [Perancangan Database (ERD)](#4-perancangan-database-erd)
5. [Class Diagram](#5-class-diagram)
6. [Deployment Diagram](#6-deployment-diagram)
7. [Sequence Diagram](#7-sequence-diagram)

---

## 1. Pendahuluan

Dokumen ini berisi rancangan model perangkat lunak sistem BUMDes Jabar, sebuah platform marketplace berbasis aplikasi mobile (Flutter) untuk Pembeli & Penjual dan backend API (Laravel 11) yang juga melayani moderasi Admin. Seluruh diagram pada dokumen ini diturunkan langsung dari Software Requirements Specification (SRS) v3.0 dan struktur source code proyek (model Eloquent, migrasi database, dan routes API), sehingga konsisten dengan implementasi aktual.

Komponen sistem terdiri dari:

- **Aplikasi Mobile (Flutter)** - digunakan oleh Pembeli dan Penjual (BUMDes)
- **Backend API (Laravel 11)**, autentikasi token via Sanctum
- **Database MySQL 8**
- **Payment Gateway Midtrans Snap**, didukung jalur alternatif unggah bukti transfer manual
- **Panel Admin** untuk moderasi toko, produk, dan pelaporan

### 1.1 Aktor Sistem

| Aktor | Deskripsi |
| --- | --- |
| Pembeli | Pengguna yang mencari, membeli produk/jasa, melakukan pembayaran, dan memberi ulasan. |
| Penjual | Pengguna pemilik BUMDes yang mengelola toko, produk/jasa, serta memproses pesanan masuk. |
| Admin | Mengelola moderasi toko, produk, pengguna, serta memantau laporan platform. |
| Midtrans | Pihak ketiga (payment gateway) yang memproses pembayaran online dan mengirim notifikasi webhook. |

### 1.2 Daftar Diagram

- **Use Case Diagram** - interaksi aktor dengan fungsi sistem
- **Activity Diagram** - alur proses Checkout, Pembayaran, hingga Ulasan
- **Perancangan Database (ERD)** - struktur tabel & relasi sesuai migration Laravel
- **Class Diagram** - model Eloquent beserta atribut, method, dan relasi
- **Deployment Diagram** - arsitektur fisik & komunikasi antar komponen
- **Sequence Diagram** - alur rinci Checkout → Pembayaran Midtrans → Konfirmasi Pesanan

---

## 2. Use Case Diagram

Diagram berikut menggambarkan interaksi tiga aktor utama (Pembeli, Penjual, Admin) serta sistem eksternal Midtrans dengan 23 use case inti pada sistem BUMDes Jabar, dikelompokkan berdasarkan modul: Akun, Toko & Produk, Transaksi, Pembayaran, Ulasan & Laporan, serta Moderasi Admin.

Aktor: **Tamu (Guest)**, **Pembeli**, **Penjual**, **Admin** - sesuai bab 2.3 SRS dan hak akses pada `routes/api.php`.

```mermaid
flowchart LR
    Tamu(["👤 Tamu / Guest"])
    Pembeli(["👤 Pembeli"])
    Penjual(["👤 Penjual (BUMDes)"])
    Admin(["👤 Admin"])

    subgraph SYS["Sistem BUMDes Jabar"]
        direction TB
        UC1(("Registrasi Akun"))
        UC2(("Login"))
        UC3(("Logout"))
        UC4(("Lihat & Cari Produk/Jasa"))
        UC5(("Filter & Kategori Produk"))
        UC6(("Lihat Detail Produk"))
        UC7(("Kelola Profil"))
        UC8(("Kelola Profil Toko"))
        UC9(("Tambah Produk/Jasa"))
        UC10(("Edit Produk/Jasa"))
        UC11(("Hapus Produk/Jasa"))
        UC12(("Kelola Keranjang"))
        UC13(("Checkout / Buat Pesanan"))
        UC14(("Bayar via Payment Gateway"))
        UC15(("Lihat Riwayat Pesanan"))
        UC16(("Update Status Pesanan"))
        UC17(("Konfirmasi Penerimaan Pesanan"))
        UC18(("Beri Ulasan Produk"))
        UC19(("Lihat Laporan Toko"))
        UC20(("Moderasi Produk"))
        UC21(("Lihat Laporan Platform"))
        UC22(("Kelola Pengguna & Toko"))
    end

    Tamu --> UC1
    Tamu --> UC2
    Tamu --> UC4
    Tamu --> UC5
    Tamu --> UC6

    Pembeli --> UC2
    Pembeli --> UC3
    Pembeli --> UC4
    Pembeli --> UC5
    Pembeli --> UC6
    Pembeli --> UC7
    Pembeli --> UC12
    Pembeli --> UC13
    Pembeli --> UC14
    Pembeli --> UC15
    Pembeli --> UC17
    Pembeli --> UC18

    Penjual --> UC2
    Penjual --> UC3
    Penjual --> UC7
    Penjual --> UC8
    Penjual --> UC9
    Penjual --> UC10
    Penjual --> UC11
    Penjual --> UC16
    Penjual --> UC19

    Admin --> UC2
    Admin --> UC3
    Admin --> UC7
    Admin --> UC20
    Admin --> UC21
    Admin --> UC22

    UC13 -.include.-> UC12
    UC14 -.include.-> UC13
    UC17 -.include.-> UC15
    UC18 -.include.-> UC17

    style SYS fill:#f4f8ff,stroke:#2c5fae,stroke-width:2px
    style Tamu fill:#fff3cd,stroke:#b8860b
    style Pembeli fill:#d4edda,stroke:#1e7e34
    style Penjual fill:#cce5ff,stroke:#004085
    style Admin fill:#f8d7da,stroke:#a71d2a
```

> **Catatan relasi:** `Checkout/Buat Pesanan` *include* `Kelola Keranjang`; `Bayar via Payment Gateway` *include* `Checkout`; `Konfirmasi Penerimaan` *include* `Lihat Riwayat Pesanan`; `Beri Ulasan` hanya dapat dilakukan setelah `Konfirmasi Penerimaan` (status `Selesai`).

---

## 3. Activity Diagram

Alur utama: **Pembeli melakukan pemesanan hingga pembayaran**, sesuai `OrderController` & `PaymentController`.

```mermaid
flowchart TD
    Start((Mulai)) --> A[Pembeli login]
    A --> B[Cari & pilih produk/jasa]
    B --> C[Tambahkan ke keranjang]
    C --> D{Lanjut belanja?}
    D -- Tidak --> B
    D -- Ya --> E[Buka halaman keranjang]
    E --> F[Klik Checkout]
    F --> G[Isi alamat & data penerima]
    G --> H[Sistem buat Order\nstatus: Menunggu Pembayaran]
    H --> I[Sistem buat Invoice\nke Payment Gateway]
    I --> J[Pembeli diarahkan\nke halaman pembayaran]
    J --> K{Pembayaran berhasil?}
    K -- Tidak / Batal --> L[Order tetap Menunggu Pembayaran\natau Dibatalkan]
    L --> End1((Selesai))
    K -- Ya --> M[Webhook payment gateway\nupdate status pembayaran]
    M --> N[Order berubah:\nMenunggu Konfirmasi]
    N --> O[Penjual cek pesanan]
    O --> P{Penjual konfirmasi?}
    P -- Tolak --> Q[Order: Dibatalkan]
    Q --> End2((Selesai))
    P -- Terima --> R[Order: Dikonfirmasi]
    R --> S[Penjual proses pesanan]
    S --> T[Order: Diproses]
    T --> U[Penjual kirim pesanan]
    U --> V[Order: Dikirim]
    V --> W[Pembeli terima barang]
    W --> X[Pembeli konfirmasi penerimaan]
    X --> Y[Order: Selesai\ncompleted_at terisi]
    Y --> Z[Pembeli beri ulasan produk]
    Z --> End3((Selesai))

    style Start fill:#2c5fae,color:#fff
    style End1 fill:#a71d2a,color:#fff
    style End2 fill:#a71d2a,color:#fff
    style End3 fill:#1e7e34,color:#fff
```

---


## 4. Perancangan Database (ERD)

Disusun dari migration: `users`, `stores`, `categories`, `products`, `carts`, `orders`, `order_items`, `payments`, `reviews`.

```mermaid
erDiagram
    USERS ||--o| STORES : "memiliki (1 akun = 1 toko)"
    USERS ||--o{ ORDERS : "memesan sebagai buyer"
    USERS ||--o{ CARTS : "memiliki"
    USERS ||--o{ REVIEWS : "menulis sebagai buyer"

    STORES ||--o{ PRODUCTS : "menjual"
    STORES ||--o{ ORDERS : "menerima"

    CATEGORIES ||--o{ PRODUCTS : "mengelompokkan"

    PRODUCTS ||--o{ CARTS : "ditambahkan ke"
    PRODUCTS ||--o{ ORDER_ITEMS : "dipesan dalam"
    PRODUCTS ||--o{ REVIEWS : "diulas pada"

    ORDERS ||--o{ ORDER_ITEMS : "berisi"
    ORDERS ||--o| PAYMENTS : "memiliki"
    ORDERS ||--o{ REVIEWS : "menghasilkan"

    USERS {
        bigint id PK
        string name
        string email UK
        timestamp email_verified_at
        string password
        enum role "Pembeli|Penjual|Admin"
        string phone
        text address
        string photo_url
        timestamps created_at_updated_at
    }

    STORES {
        bigint id PK
        bigint user_id FK
        string store_name
        text description
        string village
        string district
        string regency
        string contact_phone
        string bank_account_number
        string bank_name
        string bank_account_holder
        string store_photo_url
        boolean is_active
    }

    CATEGORIES {
        bigint id PK
        string name UK
        text description
    }

    PRODUCTS {
        bigint id PK
        bigint store_id FK
        bigint category_id FK
        string name
        enum type "produk|jasa"
        decimal price
        int stock
        text description
        string photo_url
        boolean is_active
    }

    CARTS {
        bigint id PK
        bigint user_id FK
        bigint product_id FK
        int quantity
    }

    ORDERS {
        bigint id PK
        string order_number UK
        bigint buyer_id FK
        bigint store_id FK
        enum status "MenungguPembayaran..Selesai"
        string recipient_name
        string recipient_phone
        text delivery_address
        text notes
        decimal total_price
        timestamp delivered_at
        timestamp completed_at
    }

    ORDER_ITEMS {
        bigint id PK
        bigint order_id FK
        bigint product_id FK
        int quantity
        decimal unit_price
        decimal subtotal
    }

    PAYMENTS {
        bigint id PK
        bigint order_id FK "unique"
        string proof_image_url
        enum status "Pending|Confirmed|Rejected"
        string invoice_id UK
        text invoice_url
        string payment_method
        string payment_status
        timestamp paid_at
        text rejection_reason
        timestamp confirmed_at
        timestamp rejected_at
    }

    REVIEWS {
        bigint id PK
        bigint product_id FK
        bigint buyer_id FK
        bigint order_id FK
        int rating "1-5"
        text comment
    }
```

**Catatan kunci/constraint penting:**
- `stores.user_id` → unique relation (1 user = 1 toko, sesuai aturan bisnis 5.5 SRS).
- `carts` unik pada `(user_id, product_id)` agar satu produk tidak dobel di keranjang yang sama.
- `payments.order_id` unik (1 order = 1 payment) + `invoice_id` unik dari payment gateway.
- `reviews` unik pada `(product_id, buyer_id, order_id)` — satu ulasan per produk per transaksi.
- `orders.status` mengikuti alur: `Menunggu Pembayaran → Menunggu Konfirmasi → Dikonfirmasi → Diproses → Dikirim → Selesai` (atau `Dibatalkan`).

---

## 5. Class Diagram

Class diagram berikut merepresentasikan model Eloquent (`app/Models`) pada backend Laravel beserta atribut (`fillable` & `casts`) dan method relasi (`belongsTo`, `hasMany`, `hasOne`) sebagaimana diimplementasikan pada source code.

![Class Diagram](images/image4.png)

```mermaid
classDiagram
    class User {
        +int id
        +string name
        +string email
        +string password
        +string role
        +string phone
        +string address
        +string photo_url
        +normalizeRole() string
        +isSeller() bool
        +isBuyer() bool
        +isAdmin() bool
        +store() Store
        +orders() Order[]
        +carts() Cart[]
        +reviews() Review[]
    }

    class Store {
        +int id
        +int user_id
        +string store_name
        +string description
        +string village
        +string district
        +string regency
        +string contact_phone
        +string bank_account_number
        +string bank_name
        +string bank_account_holder
        +bool is_active
        +user() User
        +products() Product[]
        +orders() Order[]
    }

    class Category {
        +int id
        +string name
        +string description
        +products() Product[]
    }

    class Product {
        +int id
        +int store_id
        +int category_id
        +string name
        +string type
        +decimal price
        +int stock
        +string description
        +bool is_active
        +store() Store
        +category() Category
        +carts() Cart[]
        +orderItems() OrderItem[]
        +reviews() Review[]
    }

    class Cart {
        +int id
        +int user_id
        +int product_id
        +int quantity
        +user() User
        +product() Product
    }

    class Order {
        +int id
        +string order_number
        +int buyer_id
        +int store_id
        +string status
        +string recipient_name
        +string recipient_phone
        +string delivery_address
        +string notes
        +decimal total_price
        +datetime delivered_at
        +datetime completed_at
        +buyer() User
        +store() Store
        +orderItems() OrderItem[]
        +payment() Payment
        +reviews() Review[]
    }

    class OrderItem {
        +int id
        +int order_id
        +int product_id
        +int quantity
        +decimal unit_price
        +decimal subtotal
        +order() Order
        +product() Product
    }

    class Payment {
        +int id
        +int order_id
        +string proof_image_url
        +string status
        +string invoice_id
        +string invoice_url
        +string payment_method
        +string payment_status
        +datetime paid_at
        +string rejection_reason
        +order() Order
    }

    class Review {
        +int id
        +int product_id
        +int buyer_id
        +int order_id
        +int rating
        +string comment
        +product() Product
        +buyer() User
        +order() Order
    }

    User "1" --o "0..1" Store : memiliki
    User "1" --o "0..*" Order : memesan
    User "1" --o "0..*" Cart : memiliki
    User "1" --o "0..*" Review : menulis

    Store "1" --o "0..*" Product : menjual
    Store "1" --o "0..*" Order : menerima

    Category "1" --o "0..*" Product : mengelompokkan

    Product "1" --o "0..*" Cart : "ada di"
    Product "1" --o "0..*" OrderItem : "termuat dalam"
    Product "1" --o "0..*" Review : diulas

    Order "1" --o "1..*" OrderItem : berisi
    Order "1" --o "0..1" Payment : memiliki
    Order "1" --o "0..*" Review : menghasilkan
```


## 6. Deployment Diagram

Deployment diagram berikut menggambarkan arsitektur fisik sistem: perangkat mobile (Flutter) dan browser admin yang berkomunikasi via HTTPS/REST JSON ke server (Docker, Nginx + PHP-FPM, Laravel 11), yang terhubung ke MySQL 8, SMTP server, serta Midtrans Snap sebagai payment gateway eksternal (termasuk jalur webhook).

Berdasarkan arsitektur SRS (2.1, 3.4) dan struktur proyek: **Flutter mobile/web app**, **Laravel REST API**, **MySQL**, **Payment Gateway (Xendit/Midtrans)** pihak ketiga.

```mermaid
flowchart TB
    subgraph CLIENT["📱 Client Device (Android ≥8.0 / iOS ≥13 / Web)"]
        FE["Flutter App\n(bumdes_frontend)\n- UI Pembeli & Penjual\n- HTTP Client (Dio/http)"]
    end

    subgraph CDN["🌐 Internet"]
        HTTPS1[/"HTTPS / JSON REST API\nBearer Token (Sanctum)"/]
    end

    subgraph SERVER["🖥️ Application Server (Linux + Docker)"]
        direction TB
        WEB["Nginx / Web Server"]
        API["Laravel Backend API\n(bumdes_jabar/laravel)\n- Controllers\n- Sanctum Auth\n- Business Logic"]
        WEB --> API
    end

    subgraph DBSRV["🗄️ Database Server"]
        DB[("MySQL 8\nDatabase: bumdes_jabar")]
    end

    subgraph STORAGE["📦 File Storage"]
        FS["Storage Disk\n(foto produk, toko, profil)"]
    end

    subgraph EXTERNAL["💳 Pihak Ketiga"]
        PG["Payment Gateway\n(Xendit / Midtrans)\nInvoice & Webhook"]
        SMTP["SMTP Server\n(Email Verifikasi)"]
    end

    FE -- "Request/Response" --> HTTPS1
    HTTPS1 -- "Routed via /api/*" --> WEB
    API -- "Eloquent ORM (TCP 3306)" --> DB
    API -- "Read/Write file" --> FS
    API -- "Create Invoice / Webhook Callback" --> PG
    API -- "Kirim Email" --> SMTP

    style CLIENT fill:#cce5ff,stroke:#004085,stroke-width:2px
    style SERVER fill:#d4edda,stroke:#1e7e34,stroke-width:2px
    style DBSRV fill:#fff3cd,stroke:#b8860b,stroke-width:2px
    style EXTERNAL fill:#f8d7da,stroke:#a71d2a,stroke-width:2px
    style STORAGE fill:#e2e3e5,stroke:#555,stroke-width:2px
```

---
## 7. Sequence Diagram

Sequence diagram berikut menjabarkan alur rinci Checkout → Pembuatan Invoice Midtrans Snap → Pembayaran → Notifikasi Webhook → Update Status Pesanan, melibatkan Pembeli, Flutter App, `OrderController`, `PaymentController`, Database, dan Midtrans.

Skenario: **Pembeli melakukan checkout dan pembayaran** (`POST /api/orders` → `POST /api/payments/create` → webhook).

```mermaid
sequenceDiagram
    actor Pembeli
    participant App as Flutter App
    participant API as Laravel API
    participant DB as MySQL Database
    participant PG as Payment Gateway

    Pembeli ->> App: Klik "Checkout" di keranjang
    App ->> API: POST /api/orders (cart items, alamat)
    API ->> DB: Ambil data cart milik user
    DB -->> API: Data keranjang
    API ->> DB: INSERT orders (status: Menunggu Pembayaran)
    API ->> DB: INSERT order_items
    API ->> DB: DELETE/clear carts
    DB -->> API: OK
    API -->> App: 201 Created (order_number, order_id)

    App ->> API: POST /api/payments/create (order_id)
    API ->> PG: Create Invoice (amount, order_number)
    PG -->> API: invoice_id, invoice_url
    API ->> DB: INSERT/UPDATE payments (invoice_id, invoice_url)
    DB -->> API: OK
    API -->> App: 200 OK (invoice_url)
    App -->> Pembeli: Tampilkan halaman pembayaran

    Pembeli ->> PG: Bayar (transfer/e-wallet/VA)
    PG ->> API: POST /api/payments/webhook (status: PAID)
    API ->> DB: UPDATE payments SET payment_status='Paid', paid_at=now()
    API ->> DB: UPDATE orders SET status='Menunggu Konfirmasi'
    DB -->> API: OK
    API -->> PG: 200 OK (ack webhook)

    App ->> API: GET /api/orders/{id} (polling/refresh)
    API ->> DB: SELECT order + payment status
    DB -->> API: status: Menunggu Konfirmasi
    API -->> App: 200 OK (status terbaru)
    App -->> Pembeli: Notifikasi "Pembayaran berhasil"
```

---


*Dokumen ini disusun berdasarkan SRS v3.0 dan source code proyek BUMDes Jabar (Laravel 11 + Flutter), Juni 2026.*
