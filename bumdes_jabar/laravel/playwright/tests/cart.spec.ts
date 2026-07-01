import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';

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

test.describe.serial('Cart & Order - BUMDes Jabar', () => {
  let page: Page;
  const uniqueEmail = `playwright.cart.${Date.now()}@example.com`;
  const password = 'password123';

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(220000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('mendaftar akun buyer baru untuk pengujian', async () => {
    test.setTimeout(150000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/register`, 120000);
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible({ timeout: 100000 });

    await fillField(page, 'Nama Lengkap', 'Buyer Otomatis');
    await fillField(page, 'Email', uniqueEmail);
    await fillField(page, 'Password', password, true);
    await fillField(page, 'Konfirmasi Password', password);

    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });
  });

  test('login dengan akun buyer yang baru didaftarkan', async () => {
    test.setTimeout(60000);
    await fillField(page, 'Email', uniqueEmail);
    await fillField(page, 'Password', password, true);
    await page.getByRole('button', { name: 'LOGIN' }).click();

    // Berhasil login -> masuk ke Beranda (buyer)
    await expect(page.getByText('Produk Unggulan').last()).toBeVisible({ timeout: 30000 });
  });

  test('menambahkan produk ke keranjang lalu checkout', async () => {
    test.setTimeout(60000);

    // Klik salah satu produk yang stoknya tersedia (regex "Stok <angka>", bukan "Stok Habis")
    await page.getByText(/Stok \d+/).first().click();

    // Di halaman detail produk -> klik "Pesan Sekarang" (otomatis isi keranjang + pindah ke /cart)
    await page.getByRole('button', { name: 'Pesan Sekarang' }).click();

    // Tunggu halaman checkout muncul (ada Ringkasan Pesanan)
    await expect(page.getByRole('img', { name: 'Ringkasan Pesanan' })).toBeVisible({ timeout: 20000 });

    await fillField(page, 'Nama Penerima', 'Buyer Otomatis');
    await fillField(page, 'No. HP Penerima', '081234567890');
    await fillField(page, 'Alamat Pengiriman', 'Jl. Testing No. 1, Bandung');

    await page.getByRole('button', { name: 'Checkout Sekarang' }).click();

    // Setelah checkout berhasil, app pindah ke halaman Payment Gateway
    await expect(page.getByRole('heading', { name: 'Pembayaran Midtrans' })).toBeVisible({ timeout: 30000 });
  });
});