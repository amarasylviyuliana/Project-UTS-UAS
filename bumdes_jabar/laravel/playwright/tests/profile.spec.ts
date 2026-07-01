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

// Bersihkan isi field sebelum mengetik ulang (dipakai untuk field yang sudah ada nilainya / sisa dari test sebelumnya)
async function clearAndFillField(page: Page, label: string, value: string, exact: boolean = false) {
  const field = page.getByRole('textbox', { name: label, exact });
  await field.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  if (value) {
    await field.pressSequentially(value);
  }
  await page.keyboard.press('Tab');
}

test.describe.serial('Edit Profile - BUMDes Jabar', () => {
  let page: Page;
  const uniqueEmail = `playwright.profile.${Date.now()}@example.com`;

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

    await fillField(page, 'Nama Lengkap', 'Profile Otomatis');
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

  test('navigasi ke halaman Edit Profil dan menampilkan elemen form', async () => {
    test.setTimeout(60000);

    // Buka tab Profil lewat bottom navigation, lalu klik tombol Edit Profil
    await page.getByText('Profil', { exact: true }).last().click();
    await expect(page.getByRole('button', { name: 'Edit Profil' })).toBeVisible({ timeout: 15000 });
    await page.getByRole('button', { name: 'Edit Profil' }).click();

    await expect(page.getByRole('textbox', { name: 'Nama', exact: true })).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('textbox', { name: 'Telepon', exact: true })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Email', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Ubah Kata Sandi' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Simpan Perubahan' })).toBeVisible();
  });

  test('menampilkan validasi saat Nama dan Telepon dikosongkan', async () => {
    test.setTimeout(30000);

    await clearAndFillField(page, 'Nama', '', true);
    await clearAndFillField(page, 'Telepon', '', true);

    await page.getByRole('button', { name: 'Simpan Perubahan' }).click();

    await expect(page.getByText('Nama diperlukan').last()).toBeVisible();
    await expect(page.getByText('Telepon diperlukan').last()).toBeVisible();
  });

  test('berhasil memperbarui Nama dan Telepon dengan data valid', async () => {
    test.setTimeout(30000);

    await clearAndFillField(page, 'Nama', 'Profile Otomatis Updated', true);
    await clearAndFillField(page, 'Telepon', '081234567890', true);

    await page.getByRole('button', { name: 'Simpan Perubahan' }).click();

    await expect(page.getByText('Profil berhasil diperbarui').last()).toBeVisible({ timeout: 15000 });
  });

  test('menampilkan validasi pada dialog Ubah Kata Sandi', async () => {
    test.setTimeout(60000);

    // Buka kembali halaman Edit Profil (form sebelumnya pop kembali ke halaman Profil setelah sukses)
    await expect(page.getByRole('button', { name: 'Edit Profil' })).toBeVisible({ timeout: 15000 });
    await page.getByRole('button', { name: 'Edit Profil' }).click();

    await page.getByRole('button', { name: 'Ubah Kata Sandi' }).click();
    await expect(page.getByRole('button', { name: 'Simpan Password' })).toBeVisible({ timeout: 10000 });

    // Skenario 1: semua field kosong
    await page.getByRole('button', { name: 'Simpan Password' }).click();
    await expect(page.getByText('Password saat ini diperlukan').last()).toBeVisible();
    await expect(page.getByText('Password baru diperlukan').last()).toBeVisible();
    await expect(page.getByText('Konfirmasi password diperlukan').last()).toBeVisible();

    // Skenario 2: password baru kurang dari 8 karakter
    await clearAndFillField(page, 'Password Saat Ini', password, true);
    await clearAndFillField(page, 'Password Baru', '123', true);
    await clearAndFillField(page, 'Konfirmasi Password', '123', true);
    await page.getByRole('button', { name: 'Simpan Password' }).click();
    await expect(page.getByText('Password harus minimal 8 karakter').last()).toBeVisible();

    // Skenario 3: konfirmasi password tidak cocok
    await clearAndFillField(page, 'Password Baru', 'newpassword123', true);
    await clearAndFillField(page, 'Konfirmasi Password', 'beda123456', true);
    await page.getByRole('button', { name: 'Simpan Password' }).click();
    await expect(page.getByText('Password konfirmasi tidak cocok').last()).toBeVisible();

    // Tutup dialog tanpa menyimpan, agar tidak memengaruhi test berikutnya
    await page.getByRole('button', { name: 'Batal' }).click();
  });

  test('berhasil mengubah password dengan data valid', async () => {
    test.setTimeout(30000);

    await page.getByRole('button', { name: 'Ubah Kata Sandi' }).click();
    await expect(page.getByRole('button', { name: 'Simpan Password' })).toBeVisible({ timeout: 10000 });

    await clearAndFillField(page, 'Password Saat Ini', password, true);
    await clearAndFillField(page, 'Password Baru', 'newpassword123', true);
    await clearAndFillField(page, 'Konfirmasi Password', 'newpassword123', true);

    await page.getByRole('button', { name: 'Simpan Password' }).click();

    await expect(page.getByText('Password berhasil diperbarui').last()).toBeVisible({ timeout: 15000 });
  });
});