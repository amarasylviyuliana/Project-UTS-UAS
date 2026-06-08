# Helper script to prepare and start the canonical backend (bumdes_jabar/laravel)
# Run this from repository root (Project-UTS-UAS)

Set-StrictMode -Version Latest

Push-Location "bumdes_jabar/laravel"
Write-Output "Installing composer dependencies..."
composer install

if (-not (Test-Path .env)) {
  Copy-Item .env.example .env
  php artisan key:generate
}

Write-Output "Running migrations (with seeder)..."
php artisan migrate --seed

Write-Output "Starting development server on http://127.0.0.1:8000"
php artisan serve --host=127.0.0.1 --port=8000

Pop-Location
