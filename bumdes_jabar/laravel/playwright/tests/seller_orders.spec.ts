import { test, expect, Page } from '@playwright/test';

const BASE_URL = 'http://localhost:49800';
const SELLER_EMAIL = 'seller.garut@bumdes.id';
const SELLER_PASSWORD = '12345678';

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

test.describe.serial('Pesanan Masuk (Order Management) Seller - BUMDes Jabar', () => {
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

  test('navigasi ke tab Pesanan dan menampilkan seluruh tab status', async () => {
    test.setTimeout(30000);

    await page.getByRole('tab', { name: 'Pesanan', exact: true }).click();

    await expect(page.getByText('Pesanan Masuk')).toBeVisible({ timeout: 15000 });

    // Verifikasi filter status pesanan tampil (pakai regex, sesuai label asli di UI)
    const statusFilters = [
      /Menunggu Konfirmasi/,
      /Sedang Diproses/,
      /Sedang Dikirim/,
      /Selesai/,
      /Dibatalkan/,
    ];
    for (const label of statusFilters) {
      await expect(page.getByRole('button', { name: label }).first()).toBeVisible({ timeout: 10000 });
    }
  });

  test('menampilkan daftar pesanan pada tab Semua', async () => {
    test.setTimeout(40000);

    // Tunggu loading selesai: list pesanan, empty state, ATAU error state (jaga-jaga)
    await Promise.race([
      page.getByText(/Belum ada pesanan/).waitFor({ state: 'visible', timeout: 30000 }).catch(() => {}),
      page.locator('text=Rp').first().waitFor({ state: 'visible', timeout: 30000 }).catch(() => {}),
      page.getByRole('button', { name: 'Coba Lagi' }).waitFor({ state: 'visible', timeout: 30000 }).catch(() => {}),
    ]);

    const hasEmptyState = await page.getByText(/Belum ada pesanan/).isVisible();
    const hasError = await page.getByRole('button', { name: 'Coba Lagi' }).isVisible();

    if (hasError) {
      // Kalau error muncul, klik "Coba Lagi" sekali sebelum menyerah
      await page.getByRole('button', { name: 'Coba Lagi' }).click();
      await Promise.race([
        page.getByText(/Belum ada pesanan/).waitFor({ state: 'visible', timeout: 15000 }).catch(() => {}),
        page.locator('text=Rp').first().waitFor({ state: 'visible', timeout: 15000 }).catch(() => {}),
      ]);
    }

    const stillEmpty = await page.getByText(/Belum ada pesanan/).isVisible();
    if (stillEmpty) {
      await expect(page.getByText(/Belum ada pesanan/)).toBeVisible();
    } else {
      await expect(page.locator('text=Rp').first()).toBeVisible({ timeout: 10000 });
    }
  });

  test('membuka detail pesanan dari daftar', async () => {
    test.setTimeout(20000);

    const hasEmptyState = await page.getByText(/Belum ada pesanan/).isVisible();
    test.skip(hasEmptyState, 'Tidak ada data pesanan untuk ditest saat ini');

    // Klik card pesanan pertama pada daftar
    await page.locator('text=Rp').first().click();

    await expect(page.getByText('Detail Pesanan')).toBeVisible({ timeout: 15000 });
  });

  test('menampilkan informasi lengkap pada Detail Pesanan', async () => {
    test.setTimeout(15000);

    const hasEmptyState = await page.getByText(/Belum ada pesanan/).isVisible();
    test.skip(hasEmptyState, 'Tidak ada data pesanan untuk ditest saat ini');

    await expect(page.getByText('Detail Pesanan')).toBeVisible();
    // Elemen umum yang selalu ada di halaman detail pesanan
    await expect(page.getByRole('button', { name: 'Segarkan status pesanan' })).toBeVisible();
  });

  test('mengonfirmasi pesanan berstatus Menunggu Konfirmasi (jika tersedia)', async () => {
    test.setTimeout(20000);

    const konfirmasiBtn = page.getByRole('button', { name: 'Konfirmasi Pesanan' });
    const isAvailable = await konfirmasiBtn.isVisible().catch(() => false);
    test.skip(!isAvailable, 'Tidak ada pesanan berstatus Menunggu Konfirmasi saat ini');

    await konfirmasiBtn.click();

    await expect(page.getByText(/Status pesanan diperbarui/)).toBeVisible({ timeout: 15000 });
  });

  test('memproses pesanan menjadi "Pesanan Sedang Disiapkan" (jika tersedia)', async () => {
    test.setTimeout(20000);

    const prosesBtn = page.getByRole('button', { name: 'Pesanan Sedang Disiapkan' });
    const isAvailable = await prosesBtn.isVisible().catch(() => false);
    test.skip(!isAvailable, 'Pesanan tidak dalam status Dikonfirmasi saat ini');

    await prosesBtn.click();

    await expect(page.getByText(/Status pesanan diperbarui/)).toBeVisible({ timeout: 15000 });
  });

  test('mengirim pesanan lewat tombol "Kirim Pesanan" (jika tersedia)', async () => {
    test.setTimeout(20000);

    const kirimBtn = page.getByRole('button', { name: 'Kirim Pesanan' });
    const isAvailable = await kirimBtn.isVisible().catch(() => false);
    test.skip(!isAvailable, 'Pesanan tidak dalam status Dikonfirmasi/Diproses saat ini');

    await kirimBtn.click();

    await expect(page.getByText(/Status pesanan diperbarui/)).toBeVisible({ timeout: 15000 });
  });

  test('menampilkan dialog konfirmasi sebelum membatalkan pesanan (jika tersedia)', async () => {
    test.setTimeout(20000);

    const batalkanBtn = page.getByRole('button', { name: 'Batalkan Pesanan' });
    const isAvailable = await batalkanBtn.isVisible().catch(() => false);
    test.skip(!isAvailable, 'Tidak ada pesanan yang bisa dibatalkan saat ini');

    await batalkanBtn.click();

    await expect(page.getByText('Batalkan Pesanan').first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Apakah Anda yakin ingin membatalkan/)).toBeVisible();
    await expect(page.getByRole('button', { name: 'Tidak' })).toBeVisible();
  });

  test('membatalkan aksi pembatalan pesanan (klik Tidak)', async () => {
    test.setTimeout(15000);

    const tidakBtn = page.getByRole('button', { name: 'Tidak' });
    const isAvailable = await tidakBtn.isVisible().catch(() => false);
    test.skip(!isAvailable, 'Dialog pembatalan tidak sedang terbuka');

    await tidakBtn.click();

    await expect(page.getByText(/Apakah Anda yakin ingin membatalkan/)).not.toBeVisible({ timeout: 5000 });
  });
});