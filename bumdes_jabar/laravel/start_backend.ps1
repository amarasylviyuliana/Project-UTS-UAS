# Helper script to prepare and start the canonical backend (bumdes_jabar/laravel)
# Run this from repository root (Project-UTS-UAS)

Set-StrictMode -Version Latest

$phpPath = "C:\laragon\bin\php\php-8.1.10-Win32-vs16-x64\php.exe"
$composerPath = "C:\laragon\bin\composer\composer.bat"

if (Test-Path $phpPath) {
  $env:PATH = "C:\laragon\bin\php\php-8.1.10-Win32-vs16-x64;C:\laragon\bin\composer;" + $env:PATH
}

$phpCmd = if (Test-Path $phpPath) { $phpPath } else { "php" }
$composerCmd = if (Test-Path $composerPath) { $composerPath } else { "composer" }

Push-Location "bumdes_jabar/laravel"
Write-Output "Installing composer dependencies..."
& $composerCmd install

if (-not (Test-Path .env)) {
  Copy-Item .env.example .env
}

$envContent = Get-Content .env -Raw
if ($envContent -notmatch '(^|\r?\n)APP_KEY=.+') {
  Write-Output "Generating application key..."
  & $phpCmd artisan key:generate
}

Write-Output "Running migrations (with seeder)..."
& $phpCmd artisan migrate --seed

Write-Output "Starting development server on http://127.0.0.1:8000"
& $phpCmd artisan serve --host=127.0.0.1 --port=8000

Pop-Location
