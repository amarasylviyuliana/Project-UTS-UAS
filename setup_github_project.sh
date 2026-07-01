#!/bin/bash

# ============================================================
# GitHub Project Setup Script - BUMDes Jabar
# Project: amarasylviyuliana/Project-UTS-UAS
# GitHub Project Board: https://github.com/users/amarasylviyuliana/projects/4
# Author: PM Script Generator
# ============================================================

set -e

# ─── CONFIG ──────────────────────────────────────────────────
REPO="amarasylviyuliana/Project-UTS-UAS"
PROJECT_NUMBER=4
PROJECT_OWNER="amarasylviyuliana"

# Team members
PM="shevaheizatul"
BACKEND1="amarasylviyuliana"
BACKEND2="adhiryansyah20"
FRONTEND1="abdillahsyafiqgaos"
FRONTEND2="hilmanda14"
QA1="arilbotak24"
QA2="yunita-nrn"

# ─── COLORS (terminal output) ────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_skip()    { echo -e "${YELLOW}[SKIP]${NC} $1 (already exists)"; }
log_error()   { echo -e "${RED}[ERR]${NC}  $1"; }
log_section() { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ─── PREREQ CHECK ────────────────────────────────────────────
check_prerequisites() {
  log_section "Checking Prerequisites"
  for cmd in gh jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "'$cmd' is not installed. Please install it first."
      exit 1
    fi
    log_success "$cmd found"
  done

  if ! gh auth status &>/dev/null; then
    log_error "Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
  fi
  log_success "GitHub CLI authenticated"
}

# ─── HELPER: check if label exists ───────────────────────────
label_exists() {
  gh label list --repo "$REPO" --json name | jq -r '.[].name' | grep -qx "$1"
}

# ─── HELPER: check if milestone exists ───────────────────────
milestone_exists() {
  gh api "repos/$REPO/milestones" --jq '.[].title' | grep -qx "$1"
}

# ─── HELPER: check if issue exists (by exact title) ──────────
issue_exists() {
  local title="$1"
  gh issue list --repo "$REPO" --state all --limit 200 --json title \
    | jq -r '.[].title' | grep -qFx "$title"
}

# ─── HELPER: get milestone number by title ───────────────────
get_milestone_number() {
  gh api "repos/$REPO/milestones" --jq ".[] | select(.title==\"$1\") | .number"
}

# ─── HELPER: get project ID (GraphQL) ────────────────────────
get_project_id() {
  gh api graphql -f query='
    query($owner: String!, $number: Int!) {
      user(login: $owner) {
        projectV2(number: $number) { id }
      }
    }' -f owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" \
    --jq '.data.user.projectV2.id'
}

# ─── HELPER: add issue to project board ──────────────────────
add_issue_to_project() {
  local issue_url="$1"
  local project_id="$2"
  local issue_node_id

  issue_node_id=$(gh api graphql -f query='
    query($url: URI!) {
      resource(url: $url) { ... on Issue { id } }
    }' -f url="$issue_url" --jq '.data.resource.id' 2>/dev/null || echo "")

  if [ -n "$issue_node_id" ]; then
    gh api graphql -f query='
      mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
          item { id }
        }
      }' -f projectId="$project_id" -f contentId="$issue_node_id" &>/dev/null || true
  fi
}

# ════════════════════════════════════════════════════════════
# 1. LABELS
# ════════════════════════════════════════════════════════════
create_labels() {
  log_section "Creating Labels"

  declare -A LABELS
  # Role labels
  LABELS["role: PM"]="0052cc"
  LABELS["role: Backend"]="1d76db"
  LABELS["role: Frontend"]="0075ca"
  LABELS["role: QA"]="e4e669"

  # Priority labels
  LABELS["priority: high"]="d93f0b"
  LABELS["priority: medium"]="fbca04"
  LABELS["priority: low"]="0e8a16"

  # Type labels
  LABELS["type: feature"]="a2eeef"
  LABELS["type: bug"]="ee0701"
  LABELS["type: documentation"]="cfd3d7"
  LABELS["type: testing"]="f9d0c4"
  LABELS["type: devops"]="bfd4f2"
  LABELS["type: design"]="d4c5f9"

  # Status labels
  LABELS["status: todo"]="ededed"
  LABELS["status: in-progress"]="fef2c0"
  LABELS["status: review"]="c2e0c6"
  LABELS["status: done"]="0e8a16"
  LABELS["status: blocked"]="b60205"

  # Module labels
  LABELS["module: auth"]="5319e7"
  LABELS["module: profile"]="006b75"
  LABELS["module: product"]="e11d48"
  LABELS["module: search"]="f97316"
  LABELS["module: cart-order"]="8b5cf6"
  LABELS["module: payment"]="16a34a"
  LABELS["module: report"]="0891b2"
  LABELS["module: admin"]="dc2626"

  for label in "${!LABELS[@]}"; do
    color="${LABELS[$label]}"
    if label_exists "$label"; then
      log_skip "Label '$label'"
    else
      gh label create "$label" --repo "$REPO" --color "$color" --force &>/dev/null
      log_success "Label created: $label"
    fi
  done
}

# ════════════════════════════════════════════════════════════
# 2. MILESTONES
# ════════════════════════════════════════════════════════════
create_milestones() {
  log_section "Creating Milestones"

  declare -A MILESTONES
  MILESTONES["M1: Setup & Fondasi Proyek"]="2026-04-20|Setup awal proyek: repo, CI/CD, struktur folder, DB schema, wireframe"
  MILESTONES["M2: Auth & Profil"]="2026-05-04|Implementasi registrasi, login JWT, manajemen profil pengguna & toko"
  MILESTONES["M3: Produk, Pencarian & Keranjang"]="2026-05-18|Fitur kelola produk, pencarian real-time, filter, keranjang & pemesanan"
  MILESTONES["M4: Pembayaran & Laporan"]="2026-06-01|Integrasi payment gateway, callback, laporan transaksi & riwayat"
  MILESTONES["M5: Testing, Polish & Release"]="2026-06-15|QA penuh, bug fixing, performance tuning, dokumentasi final & deploy"

  for milestone in "${!MILESTONES[@]}"; do
    IFS='|' read -r due_date description <<< "${MILESTONES[$milestone]}"
    if milestone_exists "$milestone"; then
      log_skip "Milestone '$milestone'"
    else
      gh api "repos/$REPO/milestones" \
        -X POST \
        -f title="$milestone" \
        -f description="$description" \
        -f due_on="${due_date}T23:59:59Z" \
        -f state="open" &>/dev/null
      log_success "Milestone created: $milestone"
    fi
  done
}

# ════════════════════════════════════════════════════════════
# 3. ISSUES
# ════════════════════════════════════════════════════════════
create_issues() {
  log_section "Creating Issues"
  local project_id
  project_id=$(get_project_id)
  log_info "Project ID: $project_id"

  # ── Helper to create one issue ─────────────────────────────
  make_issue() {
    local title="$1"
    local body="$2"
    local assignee="$3"
    local milestone_title="$4"
    local labels="$5"

    if issue_exists "$title"; then
      log_skip "Issue: $title"
      return
    fi

    local milestone_num
    milestone_num=$(get_milestone_number "$milestone_title")

    local issue_url
    issue_url=$(gh issue create \
      --repo "$REPO" \
      --title "$title" \
      --body "$body" \
      --assignee "$assignee" \
      --milestone "$milestone_num" \
      --label "$labels" 2>/dev/null)

    log_success "Issue created: $title → $assignee"

    # Add to project board
    if [ -n "$project_id" ] && [ -n "$issue_url" ]; then
      add_issue_to_project "$issue_url" "$project_id"
    fi
  }

  # ══════════════════════════════════════════════════════════
  # MILESTONE 1: Setup & Fondasi Proyek
  # ══════════════════════════════════════════════════════════
  log_info "--- M1: Setup & Fondasi Proyek ---"

  make_issue \
    "[PM] Setup Repository & Struktur Proyek" \
    "## Deskripsi
Inisialisasi repository GitHub, branching strategy, dan struktur folder proyek.

## Tasks
- [ ] Buat repository \`Project-UTS-UAS\`
- [ ] Setup branch: \`main\`, \`develop\`, \`feature/*\`, \`hotfix/*\`
- [ ] Buat \`.gitignore\` untuk Laravel & Flutter
- [ ] Setup branch protection rules pada \`main\` dan \`develop\`
- [ ] Buat README.md awal
- [ ] Undang semua anggota tim ke repository

## Referensi SRS
- Bab 2.4 Lingkungan Operasional
- Bab 3.3 Software Interface" \
    "$PM" \
    "M1: Setup & Fondasi Proyek" \
    "role: PM,type: devops,priority: high,status: todo"

  make_issue \
    "[PM] Buat Milestones, Labels & Project Board GitHub" \
    "## Deskripsi
Setup manajemen proyek di GitHub: milestones, labels, dan project board.

## Tasks
- [ ] Buat semua labels (role, priority, type, module, status)
- [ ] Buat milestones M1–M5 dengan due date
- [ ] Setup GitHub Project Board dengan kolom: Backlog, Todo, In Progress, Review, Done
- [ ] Assign issues ke masing-masing anggota

## Referensi SRS
- Semua bab (manajemen lintas fitur)" \
    "$PM" \
    "M1: Setup & Fondasi Proyek" \
    "role: PM,type: devops,priority: high,status: todo"

  make_issue \
    "[PM] Dokumentasi SRS & Pembagian Tugas Tim" \
    "## Deskripsi
Finalisasi dokumen SRS dan distribusi task ke seluruh anggota tim.

## Tasks
- [ ] Review dan finalisasi SRS v2.0
- [ ] Buat task breakdown per anggota berdasarkan SRS
- [ ] Setup weekly standup schedule
- [ ] Buat template PR dan issue

## Referensi SRS
- Bab 1 Pendahuluan
- Bab 4 Fitur Sistem (semua)" \
    "$PM" \
    "M1: Setup & Fondasi Proyek" \
    "role: PM,type: documentation,priority: high,status: todo"

  make_issue \
    "[Backend] Setup Proyek Laravel & Konfigurasi Awal" \
    "## Deskripsi
Inisialisasi proyek Laravel sebagai backend API untuk BUMDes Jabar.

## Tasks
- [ ] Install Laravel (versi terbaru stable)
- [ ] Konfigurasi \`.env\` (DB, mail, APP_KEY)
- [ ] Setup MySQL 8 database
- [ ] Install package: \`tymon/jwt-auth\`, \`laravel/sanctum\`, \`guzzlehttp/guzzle\`
- [ ] Setup CORS middleware untuk Flutter
- [ ] Buat struktur folder: \`app/Http/Controllers/API/\`, \`app/Services/\`, \`app/Repositories/\`
- [ ] Setup Docker Compose (PHP + MySQL + Nginx)

## Referensi SRS
- Bab 2.1 Perspektif Produk
- Bab 2.4 Lingkungan Operasional
- Bab 3.3 Software Interface
- Bab 3.4 Komunikasi" \
    "$BACKEND1" \
    "M1: Setup & Fondasi Proyek" \
    "role: Backend,type: devops,priority: high,status: todo"

  make_issue \
    "[Backend] Desain & Implementasi Database Schema (MySQL)" \
    "## Deskripsi
Membuat dan mengimplementasikan skema database lengkap berdasarkan ERD dari SRS.

## Tasks
- [ ] Buat migration: \`users\`, \`stores\`, \`products\`, \`categories\`
- [ ] Buat migration: \`orders\`, \`order_items\`, \`payments\`
- [ ] Buat migration: \`reviews\`, \`carts\`, \`cart_items\`
- [ ] Setup foreign key & index yang diperlukan
- [ ] Buat seeder untuk data dummy (kategori, admin, produk contoh)
- [ ] Buat factory untuk testing

## Referensi SRS
- Lampiran B - Perancangan Database (ERD)
- Bab 4.3 Produk & Jasa
- Bab 4.5 Keranjang
- Bab 4.6 Pembayaran" \
    "$BACKEND2" \
    "M1: Setup & Fondasi Proyek" \
    "role: Backend,type: feature,priority: high,status: todo,module: admin"

  make_issue \
    "[Frontend] Setup Proyek Flutter & Konfigurasi Awal" \
    "## Deskripsi
Inisialisasi proyek Flutter untuk aplikasi mobile BUMDes Jabar.

## Tasks
- [ ] Buat proyek Flutter baru
- [ ] Install dependencies: \`http\`, \`shared_preferences\`, \`provider\` / \`riverpod\`
- [ ] Install: \`dio\`, \`flutter_secure_storage\`, \`go_router\`
- [ ] Setup struktur folder: \`lib/screens/\`, \`lib/widgets/\`, \`lib/services/\`, \`lib/models/\`
- [ ] Setup tema Material Design (warna, font)
- [ ] Konfigurasi flavor: dev & production
- [ ] Setup \`pubspec.yaml\` lengkap

## Referensi SRS
- Bab 2.1 Perspektif Produk (Mobile App Flutter)
- Bab 3.1 UI (Flutter + Material Design)
- Bab 3.2 Hardware" \
    "$FRONTEND1" \
    "M1: Setup & Fondasi Proyek" \
    "role: Frontend,type: devops,priority: high,status: todo"

  make_issue \
    "[Frontend] Desain UI/UX Wireframe & Design System" \
    "## Deskripsi
Membuat wireframe dan design system berdasarkan mockup UI/UX di SRS.

## Tasks
- [ ] Review UI mockup dari SRS (Lampiran B - UI/UX)
- [ ] Buat design system: warna, tipografi, spacing, komponen dasar
- [ ] Wireframe screen: Login, Register, Home, Produk, Keranjang, Checkout, Profil
- [ ] Wireframe admin dashboard
- [ ] Buat komponen reusable: AppBar, BottomNav, ProductCard, Button
- [ ] Review dengan PM dan Backend

## Referensi SRS
- Bab 3.1 UI (Flutter + Material Design, Bahasa Indonesia)
- Lampiran B - UI/UX" \
    "$FRONTEND2" \
    "M1: Setup & Fondasi Proyek" \
    "role: Frontend,type: design,priority: high,status: todo"

  make_issue \
    "[QA] Setup Testing Environment & Test Plan" \
    "## Deskripsi
Mempersiapkan environment testing dan menyusun rencana pengujian menyeluruh.

## Tasks
- [ ] Setup Postman collection untuk API testing
- [ ] Buat test plan dokumen (unit test, integration test, UAT)
- [ ] Setup Flutter integration test environment
- [ ] Buat template bug report
- [ ] Identifikasi test case berdasarkan SRS REQ-01 hingga REQ-34
- [ ] Setup CI pipeline untuk auto-run tests (GitHub Actions)

## Referensi SRS
- Bab 4 Fitur Sistem (REQ-01 s/d REQ-34)
- Bab 5 Non-Fungsional" \
    "$QA1" \
    "M1: Setup & Fondasi Proyek" \
    "role: QA,type: testing,priority: high,status: todo"

  # ══════════════════════════════════════════════════════════
  # MILESTONE 2: Auth & Profil
  # ══════════════════════════════════════════════════════════
  log_info "--- M2: Auth & Profil ---"

  make_issue \
    "[Backend] API Registrasi & Login (REQ-01, REQ-02, REQ-03, REQ-04, REQ-05)" \
    "## Deskripsi
Implementasi endpoint autentikasi lengkap dengan JWT.

## Tasks
- [ ] \`POST /api/auth/register\` — form registrasi dengan validasi (REQ-01, REQ-02)
- [ ] \`POST /api/auth/login\` — login & issue JWT token (REQ-04)
- [ ] \`POST /api/auth/logout\` — revoke token (REQ-06)
- [ ] Email konfirmasi setelah registrasi via SMTP (REQ-03)
- [ ] Error handling & response format standar (REQ-05)
- [ ] Rate limiting pada endpoint auth
- [ ] Unit test untuk AuthController

## Referensi SRS
- Bab 4.1 Registrasi & Login (REQ-01 s/d REQ-06)
- Bab 5.3 Security (JWT, Bcrypt, Rate Limiting)" \
    "$BACKEND1" \
    "M2: Auth & Profil" \
    "role: Backend,type: feature,priority: high,status: todo,module: auth"

  make_issue \
    "[Backend] API Manajemen Profil (REQ-07, REQ-08, REQ-09, REQ-10)" \
    "## Deskripsi
Implementasi endpoint untuk manajemen profil pengguna dan toko.

## Tasks
- [ ] \`GET /api/profile\` — lihat profil pengguna (REQ-07)
- [ ] \`PUT /api/profile\` — edit profil (REQ-08)
- [ ] \`GET /api/store/profile\` — profil toko BUMDes (REQ-09)
- [ ] \`PUT /api/store/profile\` — update profil toko (REQ-09)
- [ ] \`PUT /api/auth/change-password\` — ganti password (REQ-10)
- [ ] Upload foto profil (storage + validation)
- [ ] Middleware auth guard pada semua endpoint profil

## Referensi SRS
- Bab 4.2 Manajemen Profil (REQ-07 s/d REQ-10)
- Bab 5.5 Aturan Bisnis (1 akun = 1 toko)" \
    "$BACKEND2" \
    "M2: Auth & Profil" \
    "role: Backend,type: feature,priority: medium,status: todo,module: profile"

  make_issue \
    "[Frontend] Screen Login & Registrasi (REQ-01, REQ-02, REQ-04)" \
    "## Deskripsi
Implementasi halaman login dan registrasi di Flutter.

## Tasks
- [ ] Screen registrasi: form nama, email, password, konfirmasi password
- [ ] Screen login: form email & password
- [ ] Validasi client-side (format email, panjang password)
- [ ] Integrasi dengan API \`/auth/register\` dan \`/auth/login\`
- [ ] Simpan JWT token ke \`flutter_secure_storage\`
- [ ] Handle error response dari API (tampilkan pesan error)
- [ ] Loading state & disable button saat proses
- [ ] Navigasi ke Home setelah login sukses

## Referensi SRS
- Bab 4.1 Registrasi & Login (REQ-01, REQ-02, REQ-04, REQ-05)
- Bab 3.1 UI (Material Design, Bahasa Indonesia)" \
    "$FRONTEND1" \
    "M2: Auth & Profil" \
    "role: Frontend,type: feature,priority: high,status: todo,module: auth"

  make_issue \
    "[Frontend] Screen Profil Pengguna & Toko (REQ-07, REQ-08, REQ-09, REQ-10)" \
    "## Deskripsi
Implementasi halaman profil pengguna dan profil toko BUMDes.

## Tasks
- [ ] Screen lihat profil pengguna (foto, nama, email)
- [ ] Screen edit profil dengan upload foto
- [ ] Screen profil toko (nama toko, deskripsi, alamat BUMDes)
- [ ] Screen ganti password
- [ ] Integrasi dengan API profil & toko
- [ ] Logout dengan clear token
- [ ] Validasi form edit profil

## Referensi SRS
- Bab 4.2 Manajemen Profil (REQ-07 s/d REQ-10)
- Bab 5.5 Aturan Bisnis (1 akun = 1 toko)" \
    "$FRONTEND2" \
    "M2: Auth & Profil" \
    "role: Frontend,type: feature,priority: medium,status: todo,module: profile"

  make_issue \
    "[QA] Testing Auth & Profil (REQ-01 s/d REQ-10)" \
    "## Deskripsi
Pengujian menyeluruh untuk fitur autentikasi dan manajemen profil.

## Test Cases
- [ ] TC-01: Register dengan data valid → sukses + email konfirmasi terkirim
- [ ] TC-02: Register dengan email duplikat → error message sesuai
- [ ] TC-03: Register dengan password lemah → validasi error
- [ ] TC-04: Login valid → JWT token diterima
- [ ] TC-05: Login password salah → error 401
- [ ] TC-06: Logout → token direvoke
- [ ] TC-07: Edit profil → data ter-update
- [ ] TC-08: Ganti password → bisa login dengan password baru
- [ ] TC-09: Akses endpoint tanpa token → 401 Unauthorized
- [ ] TC-10: Rate limiting auth → blokir setelah N percobaan

## Referensi SRS
- Bab 4.1 (REQ-01 s/d REQ-06)
- Bab 4.2 (REQ-07 s/d REQ-10)
- Bab 5.3 Security" \
    "$QA2" \
    "M2: Auth & Profil" \
    "role: QA,type: testing,priority: high,status: todo,module: auth"

  # ══════════════════════════════════════════════════════════
  # MILESTONE 3: Produk, Pencarian & Keranjang
  # ══════════════════════════════════════════════════════════
  log_info "--- M3: Produk, Pencarian & Keranjang ---"

  make_issue \
    "[Backend] API Manajemen Produk & Jasa (REQ-11, REQ-12, REQ-13, REQ-14, REQ-15)" \
    "## Deskripsi
CRUD produk/jasa untuk penjual BUMDes dengan fitur moderasi admin.

## Tasks
- [ ] \`POST /api/products\` — tambah produk (REQ-11)
- [ ] \`PUT /api/products/{id}\` — edit produk (REQ-12)
- [ ] \`DELETE /api/products/{id}\` — hapus produk (REQ-13)
- [ ] \`PATCH /api/products/{id}/stock\` — update status stok (REQ-14)
- [ ] \`POST /api/admin/products/{id}/moderate\` — moderasi admin (REQ-15)
- [ ] Upload multiple foto produk
- [ ] Validasi: nama, harga, stok, kategori wajib diisi
- [ ] Soft delete untuk produk

## Referensi SRS
- Bab 4.3 Produk & Jasa (REQ-11 s/d REQ-15)
- Bab 5.5 Aturan Bisnis (Admin bisa suspend)" \
    "$BACKEND1" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: Backend,type: feature,priority: high,status: todo,module: product"

  make_issue \
    "[Backend] API Pencarian & Kategori (REQ-16, REQ-17, REQ-18, REQ-19, REQ-20)" \
    "## Deskripsi
Endpoint pencarian produk real-time, filter, kategori, dan produk unggulan.

## Tasks
- [ ] \`GET /api/products/search?q=\` — search real-time (REQ-16)
- [ ] \`GET /api/categories\` — list kategori (REQ-17)
- [ ] \`GET /api/products/{id}\` — detail produk lengkap (REQ-18)
- [ ] \`GET /api/products?category=&min_price=&max_price=&sort=\` — filter (REQ-19)
- [ ] \`GET /api/products/featured\` — produk unggulan (REQ-20)
- [ ] Implementasi full-text search MySQL
- [ ] Pagination pada semua list endpoint

## Referensi SRS
- Bab 4.4 Pencarian (REQ-16 s/d REQ-20)" \
    "$BACKEND2" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: Backend,type: feature,priority: high,status: todo,module: search"

  make_issue \
    "[Backend] API Keranjang & Pemesanan (REQ-21, REQ-22, REQ-23, REQ-24, REQ-25)" \
    "## Deskripsi
Endpoint kelola keranjang belanja dan buat pesanan.

## Tasks
- [ ] \`GET /api/cart\` — lihat keranjang (REQ-21)
- [ ] \`POST /api/cart/items\` — tambah item ke keranjang (REQ-21)
- [ ] \`PUT /api/cart/items/{id}\` — update qty (REQ-21)
- [ ] \`DELETE /api/cart/items/{id}\` — hapus item (REQ-21)
- [ ] \`POST /api/orders\` — buat pesanan dari keranjang (REQ-22)
- [ ] Set status awal order = \`pending\` (REQ-23)
- [ ] \`PATCH /api/orders/{id}/status\` — update status order (REQ-24)
- [ ] \`POST /api/orders/{id}/confirm\` — konfirmasi penerimaan (REQ-25)
- [ ] Atomic transaction saat buat order (kurangi stok + buat order)

## Referensi SRS
- Bab 4.5 Keranjang (REQ-21 s/d REQ-25)
- Bab 5.2 Safety (Atomic transaction)" \
    "$BACKEND1" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: Backend,type: feature,priority: high,status: todo,module: cart-order"

  make_issue \
    "[Frontend] Screen Produk: List, Detail & Kelola Produk (REQ-11 s/d REQ-20)" \
    "## Deskripsi
Implementasi halaman-halaman terkait produk di Flutter.

## Tasks
- [ ] Screen home: produk unggulan & terbaru (REQ-20)
- [ ] Screen list produk dengan grid/list view
- [ ] Komponen ProductCard (foto, nama, harga, stok)
- [ ] Screen detail produk (foto galeri, deskripsi, harga, tombol beli)
- [ ] Screen search dengan real-time debounce (REQ-16)
- [ ] Screen filter & kategori (REQ-17, REQ-19)
- [ ] Screen tambah/edit produk untuk penjual (REQ-11, REQ-12)
- [ ] Upload foto produk dari kamera/galeri
- [ ] Handle stok habis

## Referensi SRS
- Bab 4.3 (REQ-11 s/d REQ-15)
- Bab 4.4 (REQ-16 s/d REQ-20)" \
    "$FRONTEND1" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: Frontend,type: feature,priority: high,status: todo,module: product"

  make_issue \
    "[Frontend] Screen Keranjang & Pemesanan (REQ-21 s/d REQ-25)" \
    "## Deskripsi
Implementasi halaman keranjang belanja dan alur pemesanan.

## Tasks
- [ ] Screen keranjang: list item, qty, total harga
- [ ] Update qty & hapus item dari keranjang
- [ ] Screen checkout: ringkasan order, alamat pengiriman
- [ ] Integrasi buat pesanan ke API
- [ ] Screen riwayat pesanan dengan status (pending, processing, shipped, done)
- [ ] Screen detail pesanan
- [ ] Tombol konfirmasi penerimaan barang
- [ ] Badge counter keranjang di AppBar

## Referensi SRS
- Bab 4.5 Keranjang (REQ-21 s/d REQ-25)" \
    "$FRONTEND2" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: Frontend,type: feature,priority: high,status: todo,module: cart-order"

  make_issue \
    "[QA] Testing Produk, Pencarian & Keranjang (REQ-11 s/d REQ-25)" \
    "## Deskripsi
Pengujian fitur produk, pencarian, dan keranjang.

## Test Cases
- [ ] TC-11: Tambah produk valid → muncul di list
- [ ] TC-12: Tambah produk tanpa foto → validasi error atau allowed
- [ ] TC-13: Edit produk → data ter-update
- [ ] TC-14: Hapus produk → soft delete, tidak muncul di publik
- [ ] TC-15: Update stok 0 → status habis
- [ ] TC-16: Search real-time → hasil relevan muncul
- [ ] TC-17: Filter kategori + harga → hasil sesuai filter
- [ ] TC-18: Tambah ke keranjang → qty ter-update
- [ ] TC-19: Buat order → stok berkurang, order status = pending
- [ ] TC-20: Konfirmasi order → status berubah
- [ ] TC-21: Moderasi admin → produk bisa disuspend

## Referensi SRS
- Bab 4.3 (REQ-11 s/d REQ-15)
- Bab 4.4 (REQ-16 s/d REQ-20)
- Bab 4.5 (REQ-21 s/d REQ-25)" \
    "$QA1" \
    "M3: Produk, Pencarian & Keranjang" \
    "role: QA,type: testing,priority: high,status: todo,module: product"

  # ══════════════════════════════════════════════════════════
  # MILESTONE 4: Pembayaran & Laporan
  # ══════════════════════════════════════════════════════════
  log_info "--- M4: Pembayaran & Laporan ---"

  make_issue \
    "[Backend] Integrasi Payment Gateway (REQ-26, REQ-27, REQ-28, REQ-29, REQ-30)" \
    "## Deskripsi
Implementasi pembayaran menggunakan payment gateway pihak ketiga (Midtrans/Xendit).

## Tasks
- [ ] Install & konfigurasi SDK payment gateway (REQ-26)
- [ ] \`POST /api/payments/create\` — buat order token / redirect URL (REQ-27)
- [ ] \`POST /api/payments/callback\` — endpoint terima callback sukses/gagal (REQ-28)
- [ ] Update status pembayaran & order otomatis saat callback (REQ-29)
- [ ] Handle retry dan penolakan transaksi (REQ-30)
- [ ] Verifikasi signature/hash dari callback
- [ ] Log setiap transaksi pembayaran
- [ ] Unit test mock payment gateway

## Referensi SRS
- Bab 4.6 Pembayaran (REQ-26 s/d REQ-30)
- Bab 2.5 Batasan (pembayaran via payment gateway pihak ketiga)
- Bab 5.2 Safety (atomic transaction)" \
    "$BACKEND2" \
    "M4: Pembayaran & Laporan" \
    "role: Backend,type: feature,priority: high,status: todo,module: payment"

  make_issue \
    "[Backend] API Laporan & Riwayat Transaksi (REQ-31, REQ-32, REQ-33, REQ-34)" \
    "## Deskripsi
Endpoint laporan untuk pembeli, penjual, dan admin.

## Tasks
- [ ] \`GET /api/transactions\` — riwayat transaksi pembeli (REQ-31)
- [ ] \`GET /api/store/report\` — laporan toko: omzet, produk terlaris (REQ-32)
- [ ] \`GET /api/admin/report\` — laporan platform: total transaksi, user baru (REQ-33)
- [ ] \`POST /api/orders/{id}/review\` — tambah review produk (REQ-34)
- [ ] \`GET /api/products/{id}/reviews\` — list review
- [ ] Export laporan ke CSV/PDF (opsional)
- [ ] Filter laporan berdasarkan tanggal

## Referensi SRS
- Bab 4.7 Laporan (REQ-31 s/d REQ-34)
- Bab 5.5 Aturan Bisnis (review setelah transaksi selesai)" \
    "$BACKEND1" \
    "M4: Pembayaran & Laporan" \
    "role: Backend,type: feature,priority: medium,status: todo,module: report"

  make_issue \
    "[Frontend] Screen Pembayaran & Checkout (REQ-26 s/d REQ-30)" \
    "## Deskripsi
Implementasi alur pembayaran via payment gateway di Flutter.

## Tasks
- [ ] Screen pilih metode pembayaran (dari opsi payment gateway)
- [ ] Redirect ke halaman pembayaran payment gateway (WebView / deep link)
- [ ] Screen menunggu pembayaran (loading state)
- [ ] Screen sukses pembayaran dengan detail order
- [ ] Screen gagal/expired pembayaran dengan opsi retry
- [ ] Tampilkan nomor order & instruksi pembayaran

## Referensi SRS
- Bab 4.6 Pembayaran (REQ-26 s/d REQ-30)
- Bab 2.5 Batasan (tanpa upload bukti transfer manual)" \
    "$FRONTEND1" \
    "M4: Pembayaran & Laporan" \
    "role: Frontend,type: feature,priority: high,status: todo,module: payment"

  make_issue \
    "[Frontend] Screen Laporan, Riwayat & Review (REQ-31 s/d REQ-34)" \
    "## Deskripsi
Implementasi halaman laporan dan riwayat untuk pembeli, penjual, dan admin.

## Tasks
- [ ] Screen riwayat transaksi pembeli (list + filter status)
- [ ] Screen laporan toko: grafik omzet, produk terlaris
- [ ] Dashboard admin: total user, total transaksi, grafik
- [ ] Screen beri review produk (rating bintang + komentar)
- [ ] Tampilkan review di halaman detail produk
- [ ] Pull to refresh di semua screen laporan

## Referensi SRS
- Bab 4.7 Laporan (REQ-31 s/d REQ-34)
- Lampiran B - Halaman Dashboard Admin" \
    "$FRONTEND2" \
    "M4: Pembayaran & Laporan" \
    "role: Frontend,type: feature,priority: medium,status: todo,module: report"

  make_issue \
    "[QA] Testing Pembayaran & Laporan (REQ-26 s/d REQ-34)" \
    "## Deskripsi
Pengujian fitur pembayaran dan laporan.

## Test Cases
- [ ] TC-22: Buat pembayaran → token/URL valid diterima
- [ ] TC-23: Simulasi callback sukses → status order = paid
- [ ] TC-24: Simulasi callback gagal → status order = failed
- [ ] TC-25: Retry pembayaran setelah gagal → bisa bayar ulang
- [ ] TC-26: Callback tanpa signature valid → ditolak 403
- [ ] TC-27: Riwayat transaksi → tampil sesuai user
- [ ] TC-28: Laporan toko → data akurat sesuai order
- [ ] TC-29: Review sebelum order selesai → tidak bisa
- [ ] TC-30: Review setelah selesai → berhasil

## Referensi SRS
- Bab 4.6 (REQ-26 s/d REQ-30)
- Bab 4.7 (REQ-31 s/d REQ-34)" \
    "$QA2" \
    "M4: Pembayaran & Laporan" \
    "role: QA,type: testing,priority: high,status: todo,module: payment"

  # ══════════════════════════════════════════════════════════
  # MILESTONE 5: Testing, Polish & Release
  # ══════════════════════════════════════════════════════════
  log_info "--- M5: Testing, Polish & Release ---"

  make_issue \
    "[QA] End-to-End Testing & UAT (Semua REQ)" \
    "## Deskripsi
Pengujian end-to-end menyeluruh mencakup semua alur pengguna utama.

## Tasks
- [ ] E2E test alur: Register → Login → Cari Produk → Beli → Bayar → Konfirmasi
- [ ] E2E test alur penjual: Login → Tambah Produk → Terima Order → Update Status
- [ ] E2E test alur admin: Login → Moderasi Produk → Lihat Laporan
- [ ] UAT dengan skenario pengguna nyata
- [ ] Regression test setelah bug fixing
- [ ] Dokumentasi hasil testing (pass/fail per REQ)
- [ ] Buat laporan testing final

## Referensi SRS
- Bab 4 Semua Fitur (REQ-01 s/d REQ-34)
- Bab 5 Non-Fungsional" \
    "$QA1" \
    "M5: Testing, Polish & Release" \
    "role: QA,type: testing,priority: high,status: todo"

  make_issue \
    "[QA] Performance & Security Testing" \
    "## Deskripsi
Pengujian performa dan keamanan sesuai kebutuhan non-fungsional SRS.

## Tasks
- [ ] Load test API: target response < 2 detik (REQ NFR)
- [ ] Test load 100 user aktif bersamaan
- [ ] Test HTTPS & TLS konfigurasi
- [ ] Pentest: SQL injection, XSS pada input form
- [ ] Test JWT expiry & refresh token
- [ ] Test rate limiting pada endpoint sensitif
- [ ] Test backup & recovery database
- [ ] Lighthouse audit untuk performa Flutter Web (jika ada)

## Referensi SRS
- Bab 5.1 Performa (load < 3 detik, API < 2 detik)
- Bab 5.3 Security (HTTPS, Bcrypt, JWT, Rate Limiting)
- Bab 5.4 Quality (Availability 99%)" \
    "$QA2" \
    "M5: Testing, Polish & Release" \
    "role: QA,type: testing,priority: high,status: todo"

  make_issue \
    "[Backend] Bug Fixing, Optimasi & API Finalisasi" \
    "## Deskripsi
Perbaikan bug dari hasil QA, optimasi query, dan finalisasi API.

## Tasks
- [ ] Fix semua bug dari laporan QA
- [ ] Optimasi query N+1 dengan eager loading
- [ ] Tambah database indexing pada kolom yang sering dicari
- [ ] Review & update API documentation (Postman/Swagger)
- [ ] Pastikan semua endpoint return format konsisten
- [ ] Setup logging & error monitoring (Sentry/Laravel Telescope)
- [ ] Final code review & cleanup

## Referensi SRS
- Bab 5.1 Performa
- Bab 5.4 Quality (Maintainable)" \
    "$BACKEND2" \
    "M5: Testing, Polish & Release" \
    "role: Backend,type: bug,priority: high,status: todo"

  make_issue \
    "[Frontend] Bug Fixing, Polish UI & Optimasi Flutter" \
    "## Deskripsi
Perbaikan bug UI, polish tampilan, dan optimasi performa Flutter.

## Tasks
- [ ] Fix semua bug UI dari laporan QA
- [ ] Polish animasi & transisi antar screen
- [ ] Optimasi image loading (caching, lazy load)
- [ ] Handle semua loading & error state dengan baik
- [ ] Test di berbagai ukuran layar (Android & iOS)
- [ ] Pastikan semua teks dalam Bahasa Indonesia
- [ ] Accessibility: font size, contrast ratio
- [ ] Final build & signing APK/IPA

## Referensi SRS
- Bab 3.1 UI (Bahasa Indonesia, navigasi sederhana)
- Bab 5.1 Performa (load < 3 detik)" \
    "$FRONTEND1" \
    "M5: Testing, Polish & Release" \
    "role: Frontend,type: bug,priority: high,status: todo"

  make_issue \
    "[PM] Dokumentasi Final & Persiapan Deploy" \
    "## Deskripsi
Finalisasi semua dokumentasi dan persiapan deployment ke production.

## Tasks
- [ ] Update README dengan panduan instalasi lengkap
- [ ] Dokumentasi deployment (Docker, server config)
- [ ] Buat panduan penggunaan aplikasi (user manual ringkas)
- [ ] Review semua PR sudah merged ke \`main\`
- [ ] Tag release v1.0.0
- [ ] Deploy backend ke server Linux + Docker
- [ ] Submit APK ke Google Play (Internal Testing)
- [ ] Final demo ke dosen/stakeholder
- [ ] Arsip dokumen SRS, hasil testing, dan dokumentasi teknis

## Referensi SRS
- Bab 2.4 Lingkungan Operasional (Server Linux + Docker, MySQL 8)
- Bab 1.3 Audiens" \
    "$PM" \
    "M5: Testing, Polish & Release" \
    "role: PM,type: documentation,priority: high,status: todo"
}

# ════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════
main() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   BUMDes Jabar — GitHub Project Setup        ║${NC}"
  echo -e "${CYAN}║   Repo: ${REPO}           ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  check_prerequisites
  create_labels
  create_milestones
  create_issues

  log_section "Setup Complete!"
  echo -e "${GREEN}✅ Labels, Milestones, & Issues berhasil dibuat!${NC}"
  echo ""
  echo -e "🔗 Repository  : https://github.com/${REPO}"
  echo -e "📋 Project Board: https://github.com/users/${PROJECT_OWNER}/projects/${PROJECT_NUMBER}"
  echo ""
  echo -e "${YELLOW}Tips:${NC}"
  echo "  - Buka Project Board dan drag issues ke kolom yang sesuai"
  echo "  - Gunakan 'gh issue list --repo $REPO' untuk lihat semua issues"
  echo "  - Gunakan filter label untuk lihat tugas per anggota"
}

main "$@"
