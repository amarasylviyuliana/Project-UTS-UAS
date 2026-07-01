import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';
const password = 'password123';

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

async function backToHomeShell(page: Page) {
  for (let i = 0; i < 10; i++) {
    const pesananTab = page.getByRole('button', { name: 'Pesanan' }).last();
    if (await pesananTab.isVisible()) break;
    const backBtn = page.getByRole('button', { name: 'Back' });
    if (await backBtn.isVisible()) await backBtn.click();
    await page.waitForTimeout(800);
  }
  await expect(page.getByRole('button', { name: 'Pesanan' }).last()).toBeVisible({ timeout: 15000 });
}

test.describe.serial('Order History & Order Detail - BUMDes Jabar', () => {
  let page: Page;
  const uniqueEmail = `playwright.order.${Date.now()}@example.com`;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(300000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('mendaftar & login akun buyer untuk pengujian', async () => {
    test.setTimeout(150000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/register`, 120000);
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible({ timeout: 100000 });

    await fillField(page, 'Nama Lengkap', 'Order Otomatis');
    await fillField(page, 'Email', uniqueEmail);
    await fillField(page, 'Password', password, true);
    await fillField(page, 'Konfirmasi Password', password);

    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });

    await fillField(page, 'Email', uniqueEmail);
    await fillField(page, 'Password', password, true);
    await page.getByRole('button', { name: 'LOGIN' }).click();

    await expect(page.getByText('Produk Unggulan').last()).toBeVisible({ timeout: 30000 });
  });

  test('membuat pesanan baru lewat checkout', async () => {
    test.setTimeout(90000);

    await page.getByText(/Stok \d+/).first().click();
    await page.getByRole('button', { name: 'Pesan Sekarang' }).click();

    await expect(page.getByRole('img', { name: 'Ringkasan Pesanan' })).toBeVisible({ timeout: 20000 });
    await fillField(page, 'Nama Penerima', 'Order Otomatis');
    await fillField(page, 'No. HP Penerima', '081234567890');
    await fillField(page, 'Alamat Pengiriman', 'Jl. Testing No. 1, Bandung');
    await page.getByRole('button', { name: 'Checkout Sekarang' }).click();

    await expect(page.getByRole('heading', { name: 'Pembayaran Midtrans' })).toBeVisible({ timeout: 30000 });
  });

  test('navigasi ke tab Pesanan dan menampilkan daftar pesanan', async () => {
    test.setTimeout(60000);

    await backToHomeShell(page);
    await page.getByRole('button', { name: 'Pesanan' }).last().click();

    await expect(page.getByText('Riwayat Pesanan')).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('tab', { name: 'Semua', exact: true })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Menunggu Bayar', exact: true })).toBeVisible();
  });

  test('pesanan baru muncul di tab Semua dan tab Menunggu Bayar', async () => {
    test.setTimeout(30000);

    await page.getByRole('tab', { name: 'Semua', exact: true }).click();
    await expect(page.getByText(/ORD-/)).toBeVisible({ timeout: 15000 });

    await page.getByRole('tab', { name: 'Menunggu Bayar', exact: true }).click();
    await expect(page.getByText(/ORD-/)).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('Menunggu Pembayaran').last()).toBeVisible();
  });

  test('membuka Order Detail dan memverifikasi informasi pesanan', async () => {
    test.setTimeout(30000);

    await page.getByText(/ORD-/).first().click();

    await expect(page.getByText('Detail Pesanan')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText(/ORD-/)).toBeVisible();
    await expect(page.getByText('Menunggu Pembayaran').last()).toBeVisible();
    await expect(page.getByText(/Rp \d+/)).toBeVisible();
    await expect(page.getByText('Daftar Produk')).toBeVisible();
  });

  test('tombol Batalkan Pesanan tampil di Order Detail', async () => {
    test.setTimeout(15000);

    await expect(page.getByRole('button', { name: 'Batalkan Pesanan' })).toBeVisible({ timeout: 10000 });
  });
});