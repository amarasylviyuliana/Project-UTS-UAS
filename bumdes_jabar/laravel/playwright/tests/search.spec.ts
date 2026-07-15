// Test suite: Search & Filter - BUMDes Jabar
// Finalized by Yunita Nur Aini - all test cases passed

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

// Ambil angka dari teks "X produk ditemukan"
async function getProductCount(page: Page): Promise<number> {
  const text = await page.getByText(/\d+ produk ditemukan/).first().textContent();
  const match = text?.match(/(\d+) produk ditemukan/);
  return match ? parseInt(match[1], 10) : -1;
}

test.describe.serial('Search & Filter Produk - BUMDes Jabar', () => {
  let page: Page;
  const uniqueEmail = `playwright.search.${Date.now()}@example.com`;
  let baselineCount = 0;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(220000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('mendaftar & login akun buyer untuk pengujian', async () => {
    test.setTimeout(150000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/register`, 120000);
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible({ timeout: 100000 });

    await fillField(page, 'Nama Lengkap', 'Search Otomatis');
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

  test('navigasi ke tab Pencarian dan menampilkan elemen pencarian', async () => {
    test.setTimeout(30000);

    await page.getByText('Pencarian', { exact: true }).last().click();

    await expect(page.getByRole('textbox', { name: 'Cari produk, toko, desa...' })).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('checkbox', { name: 'Semua', exact: true })).toBeVisible();
    await expect(page.getByRole('checkbox', { name: 'Kuliner Desa', exact: true })).toBeVisible();
    await expect(page.getByText(/\d+ produk ditemukan/).first()).toBeVisible();
  });

  test('menampilkan seluruh produk saat kategori Semua dipilih', async () => {
    test.setTimeout(30000);

    await page.getByRole('checkbox', { name: 'Semua', exact: true }).click();
    await expect(page.getByText(/\d+ produk ditemukan/).first()).toBeVisible();

    baselineCount = await getProductCount(page);
    expect(baselineCount).toBeGreaterThan(0);
  });

  test('memfilter produk berdasarkan kategori tertentu', async () => {
    test.setTimeout(30000);

    await page.getByRole('checkbox', { name: 'Kuliner Desa', exact: true }).click();
    await expect(page.getByText(/\d+ produk ditemukan/).first()).toBeVisible();

    const filteredCount = await getProductCount(page);
    expect(filteredCount).toBeLessThanOrEqual(baselineCount);
    expect(filteredCount).toBeGreaterThanOrEqual(0);

    await page.getByRole('checkbox', { name: 'Semua', exact: true }).click();
  });

  test('menampilkan pesan kosong saat kata kunci pencarian tidak ditemukan', async () => {
    test.setTimeout(30000);

    await fillField(page, 'Cari produk, toko, desa...', 'zzzznotfound12345');

    await expect(page.getByText('Tidak ada produk yang cocok')).toBeVisible({ timeout: 10000 });
    expect(await getProductCount(page)).toBe(0);
  });

  test('mengembalikan daftar produk setelah pencarian dihapus', async () => {
    test.setTimeout(30000);

    const searchField = page.getByRole('textbox', { name: 'Cari produk, toko, desa...' });
    const keyword = 'zzzznotfound12345';

    await searchField.click();
    await page.keyboard.press('End');
    for (let i = 0; i < keyword.length; i++) {
      await page.keyboard.press('Backspace');
    }

    await expect(page.getByText('Tidak ada produk yang cocok')).not.toBeVisible({ timeout: 10000 });
    const restoredCount = await getProductCount(page);
    expect(restoredCount).toBe(baselineCount);
  });
});
