import { test, expect, Page } from '@playwright/test';

const LOGIN_URL = 'http://localhost:49800/#/login';

async function openAndEnableAccessibility(page: Page, url: string, timeout: number = 100000) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
  await page.getByRole('button', { name: 'Enable accessibility' }).dispatchEvent('click');
}

test.describe('Login - BUMDes Jabar', () => {
  test.beforeAll(async ({ browser }, testInfo) => {
    testInfo.setTimeout(160000);
    const page = await browser.newPage();
    await openAndEnableAccessibility(page, LOGIN_URL, 150000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 150000 });
    await page.close();
  });

  test.beforeEach(async ({ page }) => {
    test.setTimeout(120000);
    await openAndEnableAccessibility(page, LOGIN_URL, 100000);
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible({ timeout: 100000 });
  });

  test('menampilkan elemen form login', async ({ page }) => {
    await expect(page.getByRole('textbox', { name: 'Email' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Password' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'LOGIN' })).toBeVisible();
  });

  test('menampilkan validasi saat semua field kosong', async ({ page }) => {
    await page.getByRole('button', { name: 'LOGIN' }).click();
    await expect(page.getByText('Email wajib diisi').last()).toBeVisible();
    await expect(page.getByText('Password wajib diisi').last()).toBeVisible();
  });

  test('menampilkan validasi saat format email tidak valid', async ({ page }) => {
    await page.getByRole('textbox', { name: 'Email' }).fill('emailsalah');
    await page.getByRole('textbox', { name: 'Password' }).fill('password123');
    await page.getByRole('button', { name: 'LOGIN' }).click();
    await expect(page.getByText('Masukkan email valid').last()).toBeVisible();
  });

  test('menampilkan validasi saat password kurang dari 8 karakter', async ({ page }) => {
    await page.getByRole('textbox', { name: 'Email' }).fill('test@example.com');

    const passwordField = page.getByRole('textbox', { name: 'Password' });
    await passwordField.click();
    await passwordField.pressSequentially('123');
    await page.keyboard.press('Tab');

    await page.getByRole('button', { name: 'LOGIN' }).click();
    await expect(page.getByText('Password minimal 8 karakter').last()).toBeVisible();
  });

  test('menampilkan error saat kredensial salah', async ({ page }) => {
    await page.getByRole('textbox', { name: 'Email' }).fill('tidakada@example.com');

    const passwordField = page.getByRole('textbox', { name: 'Password' });
    await passwordField.click();
    await passwordField.pressSequentially('password123');
    await page.keyboard.press('Tab');

    await page.getByRole('button', { name: 'LOGIN' }).click();
    await expect(page.getByText('Email atau password tidak valid').last()).toBeVisible({ timeout: 20000 });
  });
});