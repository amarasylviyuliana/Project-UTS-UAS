#!/bin/bash
set -e

echo "=== Starting Laravel Application ==="

echo ">>> Running migrations..."
php artisan migrate --force

echo ">>> Seeding database..."
php artisan db:seed --force

echo ">>> Clearing old cache..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear

echo ">>> DEBUG: panjang GEMINI_API_KEY = ${#GEMINI_API_KEY} karakter"
echo ">>> Caching config for production..."
php artisan config:cache
php artisan route:cache

echo ">>> Setting storage permissions..."
php artisan storage:link || true
chown -R www-data:www-data /app/storage /app/bootstrap/cache

echo ">>> Starting php-fpm + nginx via supervisor..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf