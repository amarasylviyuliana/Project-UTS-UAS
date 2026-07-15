// Test suite: Edit & Hapus Produk Seller - BUMDes Jabar
// Finalized by Yunita Nur Aini - 6 test cases, all passed

import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';
const SELLER_EMAIL = 'seller.garut@bumdes.id';
const SELLER_PASSWORD = '12345678';

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

test.describe.serial('Edit & Hapus Produk Seller - BUMDes Jabar', () => {
  let page: Page;

  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(220000);
    page = await browser.newPage();
  });

  test.afterAll(async () => {
    await page.close();
  });

  test('login sebagai seller dan masuk ke Store Dashboard', async () => {
    test.setTimeout(120000);
    await openAndEnableAccessibility(page, `${BASE_URL}/#/login`, 100000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });

    await fillField(page, 'Email', SELLER_EMAIL);
    await fillField(page, 'Password', SELLER_PASSWORD, true);
    await page.getByRole('button', { name: 'LOGIN' }).click();

    await expect(page.getByText('Produk Saya').last()).toBeVisible({ timeout: 30000 });
  });

  test('navigasi ke tab Produk dan menampilkan daftar produk seller', async () => {
    test.setTimeout(30000);

    await page.getByRole('button', { name: 'Produk Tab 2 of 5' }).click();

    await expect(page.getByRole('button', { name: 'Ubah' }).first()).toBeVisible({ timeout: 15000 });
  });

  test('berhasil mengedit produk dengan data baru', async () => {
  test.setTimeout(60000);

  // Pakai koordinat nyata supaya Flutter GestureDetector ter-trigger
  const ubahBtn = page.getByRole('button', { name: 'Ubah' }).first();
  const box = await ubahBtn.boundingBox();
  await page.mouse.click(box!.x + box!.width / 2, box!.y + box!.height / 2);

  // Tunggu form edit muncul
  await expect(page.getByRole('textbox', { name: 'Nama Produk / Jasa' })).toBeVisible({ timeout: 20000 });

  const fieldNama = page.getByRole('textbox', { name: 'Nama Produk / Jasa' });
  await fieldNama.click();
  await page.keyboard.press('End');
  await fieldNama.pressSequentially(' (Updated)');
  await page.keyboard.press('Tab');

  await page.getByRole('button', { name: 'Perbarui Produk' }).click();

  await expect(page.getByText('Produk berhasil diperbarui')).toBeVisible({ timeout: 15000 });
});

  test('produk yang diedit tampil dengan nama baru di daftar', async () => {
    test.setTimeout(20000);

    await expect(page.getByText(/(Updated)/)).toBeVisible({ timeout: 15000 });
  });

  test('menampilkan dialog konfirmasi sebelum menghapus produk', async () => {
    test.setTimeout(20000);

    await page.getByRole('button', { name: 'Hapus' }).first().click();

    await expect(page.getByText('Hapus Produk')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Anda yakin ingin menghapus/)).toBeVisible();
    await expect(page.getByRole('button', { name: 'Batal' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Hapus' })).toBeVisible();
  });

  test('membatalkan penghapusan produk', async () => {
    test.setTimeout(15000);

    await page.getByRole('button', { name: 'Batal' }).click();

    await expect(page.getByText('Hapus Produk')).not.toBeVisible({ timeout: 5000 });
    await expect(page.getByRole('button', { name: 'Ubah' }).first()).toBeVisible();
  });
});
