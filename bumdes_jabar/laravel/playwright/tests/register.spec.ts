import { test, expect, Page } from '@playwright/test';

const REGISTER_URL = 'http://localhost:49800/#/register';

async function fillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });
  await field.click();
  await field.pressSequentially(value);
  await page.keyboard.press('Tab');
}

test.describe('Register - BUMDes Jabar', () => {
  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(160000);
    const page = await browser.newPage();
    await page.goto(REGISTER_URL, { waitUntil: 'domcontentloaded', timeout: 150000 });
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible({ timeout: 150000 });
    await page.close();
  });

  test.beforeEach(async ({ page }) => {
    test.setTimeout(120000);
    await page.goto(REGISTER_URL, { waitUntil: 'domcontentloaded', timeout: 100000 });
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible({ timeout: 100000 });
  });

  test('menampilkan elemen form register', async ({ page }) => {
    await expect(page.getByRole('textbox', { name: 'Nama Lengkap' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password', exact: true })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Konfirmasi Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Daftar' })).toBeVisible();
  });

  test('menampilkan validasi saat semua field kosong', async ({ page }) => {
    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByText('Nama lengkap wajib diisi').last()).toBeVisible();
    await expect(page.getByText('Email wajib diisi').last()).toBeVisible();
    await expect(page.getByText('Password wajib diisi').last()).toBeVisible();
  });

  test('menampilkan validasi saat format email tidak valid', async ({ page }) => {
    await fillField(page, 'Nama Lengkap', 'Test User');
    await fillField(page, 'Email', 'emailtanpaat');
    await fillField(page, 'Password', 'password123', true);
    await fillField(page, 'Konfirmasi Password', 'password123');

    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByText('Email tidak valid').last()).toBeVisible();
  });

  test('menampilkan validasi saat password kurang dari 8 karakter', async ({ page }) => {
    await fillField(page, 'Nama Lengkap', 'Test User');
    await fillField(page, 'Email', 'testuser@example.com');
    await fillField(page, 'Password', '123', true);
    await fillField(page, 'Konfirmasi Password', '123');

    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByText('Password minimal 8 karakter').last()).toBeVisible();
  });

  test('menampilkan validasi saat konfirmasi password tidak sama', async ({ page }) => {
    await fillField(page, 'Nama Lengkap', 'Test User');
    await fillField(page, 'Email', 'testuser@example.com');
    await fillField(page, 'Password', 'password123', true);
    await fillField(page, 'Konfirmasi Password', 'password321');

    await page.getByRole('button', { name: 'Daftar' }).click();
    await expect(page.getByText('Password tidak sama').last()).toBeVisible();
  });

  test('berhasil mendaftar dan diarahkan ke halaman login', async ({ page }) => {
    const uniqueEmail = `playwright.test.${Date.now()}@example.com`;

    await fillField(page, 'Nama Lengkap', 'Test Otomatis');
    await fillField(page, 'Email', uniqueEmail);
    await fillField(page, 'Password', 'password123', true);
    await fillField(page, 'Konfirmasi Password', 'password123');

    await page.getByRole('button', { name: 'Daftar' }).click();

    // Setelah berhasil, app otomatis pindah ke halaman Login
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 30000 });
  });
});