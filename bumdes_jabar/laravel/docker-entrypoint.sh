#!/bin/bash
# CATATAN: sengaja TIDAK pakai `set -e` di top-level lagi.
# Alasan: kalau salah satu perintah non-kritis (migrate/seed) gagal dan
# `set -e` aktif, seluruh container langsung mati SEBELUM nginx/php-fpm
# sempat nyala -> server jadi tidak bisa diakses sama sekali dari luar
# (browser akan lihat "Failed to fetch", padahal masalahnya di deploy,
# bukan di kode login). Sekarang tiap step dijaga manual biar app tetap
# bisa jalan walau salah satu step gagal, dan errornya tetap kelihatan
# jelas di log Railway.

echo "=== Starting Laravel Application ==="

echo ">>> Running migrations..."
if ! php artisan migrate --force; then
    echo "!!! WARNING: migration gagal. Cek log di atas untuk detail error."
    echo "!!! Aplikasi tetap akan dinyalakan supaya endpoint lain (mis. login) tidak ikut mati."
fi

echo ">>> Seeding demo data (idempotent, safe to run every start)..."
php artisan db:seed --force || echo "!!! WARNING: seeding gagal, dilewati."

echo ">>> Clearing old cache..."
php artisan config:clear || true
php artisan cache:clear || true
php artisan route:clear || true

echo ">>> DEBUG: panjang GEMINI_API_KEY = ${#GEMINI_API_KEY} karakter"
echo ">>> Caching config for production..."
if ! php artisan config:cache; then
    echo "!!! WARNING: config:cache gagal (biasanya karena ada env var yang belum di-set di Railway). Lanjut tanpa config cache."
fi
php artisan route:cache || echo "!!! WARNING: route:cache gagal, dilewati."

echo ">>> Setting storage permissions..."
php artisan storage:link || true
chown -R www-data:www-data /app/storage /app/bootstrap/cache || true

echo ">>> Starting php-fpm + nginx via supervisor..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf