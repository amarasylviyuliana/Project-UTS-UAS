// Test suite: Admin CRUD Produk & Toko/BUMDes - BUMDes Jabar
// Mengikuti pola helper yang sama dengan admin.spec.ts / seller_orders.spec.ts

import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';

// Kredensial admin bawaan dari UserSeeder.php — pastikan seeder sudah dijalankan
// (php artisan db:seed) sebelum test ini di-run.
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = '12345678';

async function openAndEnableAccessibility(page: Page, url: string, timeout: number = 100000) {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
  await page.getByRole('button', { name: 'Enable accessibility' }).dispatchEvent('click');
}

async function fillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });
  await field.click();
  await field.pressSequentially(value);
  await page.keyboard.press('Tab');
}

test.describe.serial('Admin CRUD Produk & Toko/BUMDes - BUMDes Jabar', () => {
  let page: Page;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(220000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('login sebagai admin', async () => {
    test.setTimeout(120000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/login`, 100000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });

    await fillField(page, 'Email', ADMIN_EMAIL);
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

  test('navigasi ke tab BUMDes dan menampilkan daftar toko', async () => {
    test.setTimeout(30000);

    await page.getByText('BUMDES', { exact: true }).click();
    await expect(page.getByText('Kelola Toko / BUMDes')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText(/\d+ toko terdaftar/)).toBeVisible();
  });

  test('menonaktifkan toko pertama lalu mengaktifkan kembali (reversible)', async () => {
    test.setTimeout(40000);

    // Ambil tombol toggle status pada card toko pertama.
    // Tombolnya berlabel "Nonaktifkan" jika toko sedang aktif, atau
    // "Aktifkan" jika toko sedang nonaktif — kita baca state awal dulu.
    const nonaktifkanBtn = page.getByRole('button', { name: 'Nonaktifkan' }).first();
    const aktifkanBtn = page.getByRole('button', { name: 'Aktifkan' }).first();

    const startsActive = await nonaktifkanBtn.isVisible().catch(() => false);
    test.skip(!startsActive && !(await aktifkanBtn.isVisible().catch(() => false)),
      'Tidak ada toko untuk ditest saat ini');

    if (startsActive) {
      await nonaktifkanBtn.click();
      await expect(page.getByText(/berhasil dinonaktifkan/)).toBeVisible({ timeout: 15000 });
      // Kembalikan ke status semula supaya data tidak berubah permanen
      await expect(aktifkanBtn).toBeVisible({ timeout: 10000 });
      await aktifkanBtn.click();
      await expect(page.getByText(/berhasil diaktifkan/)).toBeVisible({ timeout: 15000 });
    } else {
      await aktifkanBtn.click();
      await expect(page.getByText(/berhasil diaktifkan/)).toBeVisible({ timeout: 15000 });
      // Kembalikan ke status semula
      await expect(nonaktifkanBtn).toBeVisible({ timeout: 10000 });
      await nonaktifkanBtn.click();
      await expect(page.getByText(/berhasil dinonaktifkan/)).toBeVisible({ timeout: 15000 });
    }
  });

  test('membatalkan penghapusan toko (klik Batal pada dialog konfirmasi)', async () => {
    // Timeout dinaikkan karena Admin Dashboard punya auto-refresh timer yang
    // periodik me-rebuild list, sehingga elemen bisa detach saat akan diklik.
    test.setTimeout(75000);

    // Test sebelumnya melakukan 2 request PUT berturut-turut (toggle status),
    // yang bisa race dengan auto-refresh timer dan membuat list sempat kosong.
    // Navigasi ulang DI DALAM app (bukan reload penuh — itu menghapus sesi
    // login yang cuma tersimpan di memory) untuk memicu _loadStores() ulang.
    await page.getByText('DASHBOARD', { exact: true }).click();
    await expect(page.getByText('Ringkasan Platform')).toBeVisible({ timeout: 15000 });
    await page.getByText('BUMDES', { exact: true }).click();

    // Ambil jumlah toko SEBELUM aksi, tunggu dulu sampai stabil (bukan 0/loading)
    // supaya tidak ke-capture di tengah siklus auto-refresh.
    let countBefore = 0;
    await expect(async () => {
      const text = await page.getByText(/\d+ toko terdaftar/).textContent();
      const match = text?.match(/(\d+) toko terdaftar/);
      expect(match).not.toBeNull();
      expect(Number(match![1])).toBeGreaterThan(0);
      countBefore = Number(match![1]);
    }).toPass({ timeout: 30000, intervals: [1000, 2000] });

    // Retry klik tombol Hapus: re-locate elemen tiap percobaan supaya tidak
    // memegang referensi DOM lama yang sudah di-detach oleh auto-refresh.
    await expect(async () => {
      await page.getByRole('button', { name: 'Hapus' }).first().click({ timeout: 5000 });
    }).toPass({ timeout: 40000, intervals: [1000, 2000, 3000] });

    // Dialog konfirmasi generik: title "Konfirmasi", tombol Batal & Hapus
    await expect(page.getByText('Konfirmasi')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Hapus toko .+\?/)).toBeVisible();

    await page.getByRole('button', { name: 'Batal' }).click();

    // Dialog tertutup, jumlah toko tidak berubah (tidak jadi terhapus)
    await expect(page.getByText(/Hapus toko .+\?/)).not.toBeVisible({ timeout: 5000 });
    await expect(async () => {
      const text = await page.getByText(/\d+ toko terdaftar/).textContent();
      const match = text?.match(/(\d+) toko terdaftar/);
      expect(match).not.toBeNull();
      expect(Number(match![1])).toBe(countBefore);
    }).toPass({ timeout: 10000, intervals: [500, 1000] });
  });

  test('navigasi ke tab Produk dan menampilkan daftar produk', async () => {
    test.setTimeout(30000);

    await page.getByText('PRODUK', { exact: true }).click();
    await expect(page.getByText('Manajemen Produk')).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole('textbox', { name: 'Cari nama produk atau toko...' })
    ).toBeVisible();
  });

  test('membatalkan penghapusan produk (klik Batal pada dialog konfirmasi)', async () => {
    test.setTimeout(30000);

    const hasEmptyState = await page.getByText('Belum ada produk').isVisible().catch(() => false);
    test.skip(hasEmptyState, 'Tidak ada produk untuk ditest saat ini');

    // Tombol hapus produk berupa IconButton (icon-only, tanpa label teks).
    // Kalau locator ini gagal menemukan elemen, kemungkinan ini bug
    // aksesibilitas serupa kasus card pesanan seller (tap target tidak
    // ter-expose ke accessibility tree) — catat sebagai temuan, bukan
    // salah test.
    const deleteIcon = page.locator('[aria-label="Delete"], button:has(svg)').first();

    // Fallback: cari button generik di baris pertama tabel/list produk
    // lewat locator berbasis posisi (icon delete berwarna merah).
    const anyDeleteBtn = page.getByRole('button').filter({ hasText: '' }).last();

    const clickable = (await deleteIcon.isVisible().catch(() => false)) ? deleteIcon : anyDeleteBtn;
    await clickable.click({ trial: true }).catch(async () => {
      throw new Error(
        'BUG KEMUNGKINAN: Tombol hapus produk (IconButton icon-only) tidak ' +
        'dapat ditemukan/diklik oleh accessibility tree. Perlu verifikasi manual.'
      );
    });
    await clickable.click();

    await expect(page.getByText('Konfirmasi')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Hapus produk .+\?/)).toBeVisible();

    await page.getByRole('button', { name: 'Batal' }).click();
    await expect(page.getByText(/Hapus produk .+\?/)).not.toBeVisible({ timeout: 5000 });
  });
});