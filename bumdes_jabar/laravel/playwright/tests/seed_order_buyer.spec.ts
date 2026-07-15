import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';
const BUYER_EMAIL = 'yunita12@gmail.com';
const BUYER_PASSWORD = '12345678';

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

// Skrip ini BUKAN test case penilaian — tujuannya cuma men-generate
// 1 pesanan nyata di database lokal untuk toko seller garut, supaya
// seller_orders.spec.ts punya data untuk diuji (tidak selalu skip).
test.describe.serial('Seed: Buat pesanan sebagai buyer untuk Toko Garut', () => {
  let page: Page;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(180000);
    page = await browser.newPage();
    page.on('crash', () => console.log('!!! PAGE CRASHED (renderer process crash — kemungkinan besar OOM/kehabisan RAM) !!!'));
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('login sebagai buyer', async () => {
    test.setTimeout(180000);

    page.on('console', msg => console.log(`[BROWSER ${msg.type()}]`, msg.text()));
    page.on('pageerror', err => console.log('[PAGE ERROR]', err.message));

    await openAndEnableAccessibility(page, `${BASE_URL}/#/login`, 60000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });

    await fillField(page, 'Email', BUYER_EMAIL);
    await fillField(page, 'Password', BUYER_PASSWORD, true);

    await page.screenshot({ path: 'before-login-click.png', fullPage: true });

    const [response] = await Promise.all([
      page.waitForResponse(res => res.url().includes('/api/login'), { timeout: 30000 }).catch(() => null),
      page.getByRole('button', { name: 'LOGIN' }).click(),
    ]);

    await page.screenshot({ path: 'after-login-click.png', fullPage: true });

    if (response) {
      console.log('Login response status:', response.status());
      console.log('Login response body:', await response.text().catch(() => '(gagal baca body)'));
    } else {
      console.log('Tidak ada response /api/login yang tertangkap dalam 30 detik — request kemungkinan hang di backend.');
    }

    await expect(page.getByText('Produk & Jasa Unggulan').last()).toBeVisible({ timeout: 30000 });
  });

  test('cari produk dari Toko Garut lewat tab Pencarian', async () => {
    test.setTimeout(120000); // navigasi tab baru trigger compile DDC lazy-load, bisa lambat di percobaan pertama

    await page.getByText('Pencarian', { exact: true }).last().click();
    await expect(page.getByRole('textbox', { name: 'Cari produk, toko, desa...' })).toBeVisible({ timeout: 15000 });

    await fillField(page, 'Cari produk, toko, desa...', 'Kerupuk');

    await expect(page.getByText(/\d+ produk ditemukan/).first()).toBeVisible({ timeout: 10000 });
  });

  test('menambahkan produk ke keranjang lalu checkout', async () => {
    test.setTimeout(60000);

    // Klik produk pertama hasil pencarian yang stoknya tersedia
    await page.getByText(/Stok \d+/).first().click();

    await page.getByRole('button', { name: 'Pesan Sekarang' }).click();

    await expect(page.getByRole('img', { name: 'Ringkasan Pesanan' })).toBeVisible({ timeout: 20000 });

    await fillField(page, 'Nama Penerima', 'Yunita Nur Aini');
    await fillField(page, 'No. HP Penerima', '081234567890');
    await fillField(page, 'Alamat Pengiriman', 'Jl. Testing Seed Order No. 1, Bandung');

    await page.getByRole('button', { name: 'Checkout Sekarang' }).click();

    // Order berhasil dibuat begitu masuk ke halaman Payment Gateway
    await expect(page.getByRole('heading', { name: 'Pembayaran Midtrans' })).toBeVisible({ timeout: 30000 });
  });
});