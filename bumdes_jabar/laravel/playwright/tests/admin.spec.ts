// Test suite: Admin Dashboard - BUMDes Jabar
// Mengikuti pola helper yang sama dengan order.spec.ts

import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';

// Kredensial admin bawaan dari UserSeeder.php — pastikan seeder sudah dijalankan
// (php artisan db:seed) sebelum test ini di-run.
const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = '12345678';

async function openAndEnableAccessibility(page: Page, url: string, timeout: number = 100000) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
  await page.getByRole('button', { name: 'Enable accessibility' }).dispatchEvent('click');
}

async function fillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });
  await field.click();
  await field.pressSequentially(value);
  await page.keyboard.press('Tab');
}

test.describe.serial('Admin Dashboard - BUMDes Jabar', () => {
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('login sebagai admin', async () => {
    test.setTimeout(90000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/login`, 60000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 60000 });

    await fillField(page, 'Email', ADMIN_EMAIL);
    await fillField(page, 'Password', ADMIN_PASSWORD, true);

    const loginBtn = page.getByRole('button', { name: 'LOGIN' });
    await expect(loginBtn).toBeEnabled();
    await loginBtn.click();

    // Tunggu SALAH SATU: dashboard admin muncul, atau pesan error login muncul
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

  test('menampilkan kartu statistik ringkasan platform', async () => {
    test.setTimeout(30000);

    await expect(page.getByText('Saldo Admin')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Total Toko')).toBeVisible();
    await expect(page.getByText('Pesanan', { exact: true })).toBeVisible();
    await expect(page.getByText('Pengguna', { exact: true })).toBeVisible();
  });

  test('navigasi ke tab Produk dan menampilkan daftar produk', async () => {
    test.setTimeout(30000);

    await page.getByText('PRODUK', { exact: true }).click();
    await expect(page.getByText('Manajemen Produk')).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole('textbox', { name: 'Cari nama produk atau toko...' })
    ).toBeVisible();
  });

  test('navigasi ke tab BUMDes dan menampilkan daftar toko', async () => {
    test.setTimeout(30000);

    await page.getByText('BUMDES', { exact: true }).click();
    await expect(page.getByText('Kelola Toko / BUMDes')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText(/\d+ toko terdaftar/)).toBeVisible();
  });

  test('navigasi ke tab Pesanan dan menampilkan daftar pesanan', async () => {
    test.setTimeout(30000);

    await page.getByText('PESANAN', { exact: true }).click();
    await expect(page.getByText('Daftar Pesanan')).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole('textbox', { name: 'Cari nomor pesanan atau nama pembeli...' })
    ).toBeVisible();
  });

  test('navigasi ke tab Keuangan dan menampilkan saldo platform', async () => {
    test.setTimeout(30000);

    await page.getByText('KEUANGAN', { exact: true }).click();
    await expect(page.getByText('Laporan & Analitik')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Saldo Platform Tersedia')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Tarik Saldo' })).toBeVisible();
  });

  test('navigasi ke tab Pengguna dan menampilkan daftar penjual', async () => {
    test.setTimeout(30000);

    await page.getByText('PENGGUNA', { exact: true }).click();
    await expect(page.getByRole('button', { name: 'Tambah' })).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole('textbox', { name: 'Cari nama penjual, email, atau nama toko...' })
    ).toBeVisible();
  });

  test('beralih ke sub-tab Pembeli di menu Pengguna', async () => {
    test.setTimeout(20000);

    await page.getByRole('button', { name: 'Pembeli' }).click();
    await expect(page.getByText(/\d+ Pembeli/)).toBeVisible({ timeout: 15000 });
  });

  test('menolak akses dashboard admin untuk role non-admin', async () => {
    // Skenario negatif: pastikan buyer/seller yang login TIDAK bisa masuk dashboard admin.
    // Dites di context/page terpisah supaya tidak mengganggu sesi admin di atas.
    // Timeout dinaikkan karena context baru butuh cold-start render Flutter Web lagi.
    // Cold-start context baru bisa jauh lebih lambat (compile ulang Flutter Web),
    // beri timeout jauh lebih longgar dibanding context pertama.
    test.setTimeout(180000);
    const context = await page.context().browser()!.newContext();
    const buyerPage = await context.newPage();

    await openAndEnableAccessibility(buyerPage, `${BASE_URL}/#/login`, 120000);
    await expect(buyerPage.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 60000 });

    // Akun buyer
    await fillField(buyerPage, 'Email', 'yunita12@gmail.com');
    await fillField(buyerPage, 'Password', '12345678', true);
    await buyerPage.getByRole('button', { name: 'LOGIN' }).click();

    await expect(buyerPage.getByText('Produk Unggulan').last()).toBeVisible({ timeout: 30000 });

    // Coba akses route dashboard admin secara langsung
    await buyerPage.goto(`${BASE_URL}/#/admin-dashboard`, { waitUntil: 'domcontentloaded' });
    await expect(buyerPage.getByText('Akses Tidak Diizinkan')).toBeVisible({ timeout: 15000 });

    await context.close();
  });
});