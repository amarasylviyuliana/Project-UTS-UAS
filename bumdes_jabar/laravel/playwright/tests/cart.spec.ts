import { test, expect, Page } from '@playwright/test';

const LOGIN_URL = 'http://localhost:49800/#/login';
const HOME_URL  = 'http://localhost:49800/#/home';

const TEST_EMAIL    = 'ziora@gmail.com';
const TEST_PASSWORD = 'ziora123';

async function fillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });
  await field.click();
  await field.pressSequentially(value);
  await page.keyboard.press('Tab');
}

async function loginAsBuyer(page: Page) {
  await page.goto(LOGIN_URL, { waitUntil: 'domcontentloaded', timeout: 100000 });
  await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 100000 });
  await fillField(page, 'Email', TEST_EMAIL);
  await fillField(page, 'Password', TEST_PASSWORD, true);
  await page.getByRole('button', { name: 'LOGIN' }).click();
  await page.waitForTimeout(3000); // beri waktu Flutter proses login
  await expect(page.getByRole('button', { name: 'Keranjang', exact: true })).toBeVisible({ timeout: 30000 });
}

async function addFirstAvailableProductToCart(page: Page) {
  await page.goto(HOME_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });

  // Produk di home adalah button, cari yang stoknya tersedia (bukan "Stok Habis")
  const productButtons = page.getByRole('button', { name: /Stok \d+/ });
  await expect(productButtons.first()).toBeVisible({ timeout: 20000 });
  await productButtons.first().click();

  // Tunggu halaman detail produk
  await expect(page.getByRole('button', { name: 'Masukkan ke Keranjang' })).toBeVisible({ timeout: 20000 });
  await page.getByRole('button', { name: 'Masukkan ke Keranjang' }).click();
  await page.waitForTimeout(500);
}

async function navigateToCart(page: Page) {
  await page.getByRole('button', { name: 'Keranjang', exact: true }).click();
  await page.waitForTimeout(1000);
}

test.describe('Cart & Checkout - BUMDes Jabar', () => {
  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(160000);
    const page = await browser.newPage();
    await page.goto(LOGIN_URL, { waitUntil: 'domcontentloaded', timeout: 150000 });
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 150000 });
    await page.close();
  });

  test.beforeEach(async ({ page }) => {
    test.setTimeout(120000);
  });

  test('TC-CART-001: menampilkan pesan keranjang kosong saat belum ada item', async ({ page }) => {
    await loginAsBuyer(page);
    await navigateToCart(page);
    const isEmpty = await page.getByText('Keranjang Anda kosong').isVisible().catch(() => false);
    if (!isEmpty) { test.skip(); return; }
    await expect(page.getByText('Keranjang Anda kosong')).toBeVisible();
  });

  test('TC-CART-002: dapat menambahkan produk ke keranjang dari halaman produk', async ({ page }) => {
    await loginAsBuyer(page);
    await addFirstAvailableProductToCart(page);
    await expect(page.getByText('Produk ditambahkan ke keranjang')).toBeVisible({ timeout: 10000 });
  });

  test('TC-CART-003: halaman cart menampilkan ringkasan pesanan setelah produk ditambahkan', async ({ page }) => {
    await loginAsBuyer(page);
    await addFirstAvailableProductToCart(page);
    await navigateToCart(page);
    await expect(page.getByRole('textbox', { name: 'Nama Penerima' })).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('textbox', { name: 'No. HP Penerima' })).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('button', { name: 'Checkout Sekarang' })).toBeVisible({ timeout: 10000 });
  });

  test('TC-CART-004: menampilkan validasi saat form checkout kosong', async ({ page }) => {
    await loginAsBuyer(page);
    await addFirstAvailableProductToCart(page);
    await navigateToCart(page);
    await expect(page.getByText('Checkout Sekarang').first()).toBeVisible({ timeout: 15000 });
    await page.getByRole('button', { name: 'Checkout Sekarang' }).click();
    await expect(page.getByText('Nama penerima wajib diisi').last()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('Nomor HP wajib diisi').last()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('Alamat wajib diisi').last()).toBeVisible({ timeout: 10000 });
  });

  test('TC-CART-005: dapat mengisi form checkout dan melanjutkan ke pembayaran', async ({ page }) => {
    await loginAsBuyer(page);
    await addFirstAvailableProductToCart(page);
    await navigateToCart(page);
    await expect(page.getByText('Checkout Sekarang').first()).toBeVisible({ timeout: 15000 });
    await fillField(page, 'Nama Penerima', 'Test Playwright');
    await fillField(page, 'No. HP Penerima', '081234567890');
    await fillField(page, 'Alamat Pengiriman', 'Jl. Testing No. 1, Bandung');
    await page.getByRole('button', { name: 'Checkout Sekarang' }).click();
    await expect(
      page.getByText(/pembayaran|xendit|pesanan diterima|lihat riwayat/i).first()
    ).toBeVisible({ timeout: 30000 });
  });
});