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

echo ">>> Caching config for production..."
php artisan config:cache
php artisan route:cache

echo ">>> Setting storage permissions..."
php artisan storage:link || true
chown -R www-data:www-data /app/storage /app/bootstrap/cache

echo ">>> Starting Laravel server..."
php artisan serve --host=0.0.0.0 --port=8000