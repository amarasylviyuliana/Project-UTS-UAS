// Test suite: Admin Manajemen Pengguna (Penjual & Pembeli) - BUMDes Jabar
// Mengikuti pola helper yang sama dengan admin.spec.ts / admin_crud.spec.ts

import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';

const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = '12345678';

// Data penjual baru — email dibuat unik pakai timestamp supaya tidak bentrok
// dengan data yang sudah ada tiap kali test dijalankan ulang.
const uniqueSuffix = Date.now();
const NEW_SELLER = {
  name: `Test Seller ${uniqueSuffix}`,
  email: `test.seller.${uniqueSuffix}@example.com`,
  phone: '081200000000',
  password: 'password123',
  storeName: `Toko Test ${uniqueSuffix}`,
  storePhone: '081200000001',
  village: 'Desa Testing',
  district: 'Kecamatan Testing',
  regency: 'Kabupaten Testing',
};

async function openAndEnableAccessibility(page: Page, url: string, timeout: number = 100000) {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
  await page.getByRole('button', { name: 'Enable accessibility' }).dispatchEvent('click');
}

async function fillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });

  // Scroll eksplisit dulu dan beri jeda supaya animasi scroll dalam dialog
  // (SingleChildScrollView) selesai sebelum klik — mencegah klik "kepakai"
  // untuk scroll/focus duluan (yang bisa bikin karakter pertama hilang)
  // dan mencegah overlay semantics sesaat menutupi titik klik saat scrolling.
  await field.scrollIntoViewIfNeeded();
  await page.waitForTimeout(200);

  await field.click({ force: true });
  await page.waitForTimeout(100);

  // Delay antar karakter: field dengan validator real-time bisa me-rebuild
  // widget tiap keystroke, dan pengetikan terlalu cepat bisa membuat
  // sebagian karakter "ketelan" (hilang) di tengah proses.
  await field.pressSequentially(value, { delay: 40 });
  await page.keyboard.press('Tab');
  // Beri jeda singkat supaya validator/rebuild selesai sebelum field berikutnya
  await page.waitForTimeout(150);

  // Verifikasi nilai yang ter-input sesuai — kalau tidak, retry sekali
  const actual = await field.inputValue().catch(() => '');
  if (actual !== value) {
    await field.fill('');
    await field.pressSequentially(value, { delay: 40 });
    await page.keyboard.press('Tab');
    await page.waitForTimeout(150);
  }
}

test.describe.serial('Admin Manajemen Pengguna - BUMDes Jabar', () => {

  let page: Page;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(220000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('login sebagai admin', async () => {
    // Timeout dinaikkan: Flutter Web cold-start bisa mepet ke 100 detik
    // sendirian kalau environment sedang berat (mis. banyak tab browser
    // lain terbuka bersamaan), menyisakan sedikit waktu untuk sisa langkah.
    test.setTimeout(200000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/login`, 150000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });

    await fillField(page, 'Email', ADMIN_EMAIL, true);
    await fillField(page, 'Password', ADMIN_PASSWORD, true);

    const loginBtn = page.getByRole('button', { name: 'LOGIN' });
    await expect(loginBtn).toBeEnabled();
    await loginBtn.click();

    const dashboardMarker = page.getByText('Ringkasan Platform');
    const loginError = page.getByText(/Email atau password salah|Login gagal|Invalid credentials/i);

    await expect(async () => {
      const success = await dashboardMarker.isVisible().catch(() => false);
      const failed = await loginError.isVisible().catch(() => false);
      expect(success || failed).toBe(true);
    }).toPass({ timeout: 45000, intervals: [500, 1000, 2000] });

    if (await loginError.isVisible().catch(() => false)) {
      throw new Error('Login gagal: kredensial admin ditolak server.');
    }

    await expect(dashboardMarker).toBeVisible({ timeout: 10000 });
  });

  test('navigasi ke tab Pengguna dan menampilkan daftar penjual', async () => {
    test.setTimeout(30000);

    await page.getByText('PENGGUNA', { exact: true }).click();
    await expect(page.getByRole('button', { name: 'Tambah' })).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole('textbox', { name: 'Cari nama penjual, email, atau nama toko...' })
    ).toBeVisible();
  });

  test('validasi form Tambah Penjual menampilkan pesan saat field kosong', async () => {
    test.setTimeout(30000);

    await page.getByRole('button', { name: 'Tambah' }).click();
    // Judul dialog kadang tidak ter-expose ke accessibility tree (mirip
    // kasus IconButton lain), jadi pakai elemen form yang pasti ada
    // sebagai penanda dialog sudah terbuka.
    const daftarkanBtn = page.getByRole('button', { name: 'Daftarkan' });
    await expect(daftarkanBtn).toBeVisible({ timeout: 10000 });
    await expect(page.getByRole('textbox', { name: 'Nama', exact: true })).toBeVisible();

    // Klik Daftarkan tanpa mengisi field apa pun
    await daftarkanBtn.click();

    // Catatan: SnackBar "Mohon lengkapi semua field..." dirender di level
    // Scaffold utama, sedangkan dialog modal masih terbuka di atasnya —
    // Flutter mengecualikan semantics konten di bawah modal barrier aktif,
    // sehingga SnackBar itu tidak reliable dideteksi lewat automation
    // selama dialog masih terbuka (kemungkinan juga kurang terlihat oleh
    // pengguna asli karena tertutup dialog — worth dicatat sebagai temuan
    // UX terpisah). Validasi cukup lewat pesan error inline per field,
    // yang sudah terbukti muncul dan berfungsi benar.
    await expect(page.getByText('Wajib diisi').first()).toBeVisible({ timeout: 10000 });

    // Tutup dialog untuk test berikutnya
    await page.getByRole('button', { name: 'Batal' }).click();
    await expect(daftarkanBtn).not.toBeVisible({ timeout: 5000 });
  });

  test('menambahkan penjual baru dengan data lengkap dan valid', async () => {
    test.setTimeout(120000);

    await page.getByRole('button', { name: 'Tambah' }).click();
    await expect(page.getByRole('textbox', { name: 'Nama', exact: true })).toBeVisible({ timeout: 10000 });

    await fillField(page, 'Nama', NEW_SELLER.name, true);
    await fillField(page, 'Email', NEW_SELLER.email, true);
    await fillField(page, 'Nomor Telepon', NEW_SELLER.phone, true);
    await fillField(page, 'Password', NEW_SELLER.password, true);
    await fillField(page, 'Nama BUMDes/Toko', NEW_SELLER.storeName, true);
    await fillField(page, 'Nomor Telepon Toko', NEW_SELLER.storePhone, true);
    await fillField(page, 'Desa', NEW_SELLER.village, true);
    await fillField(page, 'Kecamatan', NEW_SELLER.district, true);
    await fillField(page, 'Kabupaten/Kota', NEW_SELLER.regency, true);

    await page.getByRole('button', { name: 'Daftarkan' }).click();

    await expect(
      page.getByText(`Penjual ${NEW_SELLER.name} berhasil ditambahkan dan toko langsung aktif`)
    ).toBeVisible({ timeout: 20000 });

    // Pastikan penjual baru muncul di daftar
    await expect(page.getByText(NEW_SELLER.name).first()).toBeVisible({ timeout: 15000 });
  });

  test('menghapus penjual test yang baru dibuat (cleanup)', async () => {
    test.setTimeout(40000);

    // Cari card penjual yang baru dibuat, lalu klik tombol hapus (icon-only)
    // di baris/card yang sama. Kalau locator ini gagal menemukan tombolnya,
    // kemungkinan ini bug aksesibilitas serupa kasus lain yang sudah
    // ditemukan sebelumnya (IconButton tanpa label ter-expose ke a11y tree).
    const sellerRow = page.getByText(NEW_SELLER.name).first().locator('xpath=ancestor::*[3]');
    const deleteBtn = sellerRow.getByRole('button').last();

    await deleteBtn.click({ trial: true }).catch(async () => {
      throw new Error(
        'BUG KEMUNGKINAN: Tombol hapus penjual (IconButton icon-only) tidak ' +
        'dapat ditemukan/diklik oleh accessibility tree. Perlu verifikasi manual.'
      );
    });
    await deleteBtn.click();

    await expect(page.getByText('Konfirmasi')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(`Hapus pengguna ${NEW_SELLER.name}?`)).toBeVisible();

    await page.getByRole('button', { name: 'Hapus' }).click();

    await expect(page.getByText(`Pengguna ${NEW_SELLER.name} berhasil dihapus`)).toBeVisible({
      timeout: 15000,
    });
    await expect(page.getByText(NEW_SELLER.name)).not.toBeVisible({ timeout: 10000 });
  });

  test('beralih ke sub-tab Pembeli dan membatalkan penghapusan pembeli', async () => {
    test.setTimeout(30000);

    await page.getByRole('button', { name: 'Pembeli' }).click();
    await expect(page.getByText(/\d+ Pembeli/)).toBeVisible({ timeout: 15000 });

    const hasEmptyState = await page
      .getByText('Belum ada pembeli terdaftar')
      .isVisible()
      .catch(() => false);
    test.skip(hasEmptyState, 'Tidak ada pembeli untuk ditest saat ini');

    const deleteBtn = page.getByRole('button').filter({ hasText: '' }).last();
    await deleteBtn.click({ trial: true }).catch(async () => {
      throw new Error(
        'BUG KEMUNGKINAN: Tombol hapus pembeli (IconButton icon-only) tidak ' +
        'dapat ditemukan/diklik oleh accessibility tree. Perlu verifikasi manual.'
      );
    });
    await deleteBtn.click();

    await expect(page.getByText('Konfirmasi')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Hapus pembeli .+\?/)).toBeVisible();

    await page.getByRole('button', { name: 'Batal' }).click();
    await expect(page.getByText(/Hapus pembeli .+\?/)).not.toBeVisible({ timeout: 5000 });
  });
});