# Laravel Backend Stub for Bumdes

This folder contains the Laravel backend API stub required to support frontend checkout and order history.

## Setup

1. Install dependencies:

   ```bash
   cd backend
   composer install
   ```

2. Copy environment file:

   ```bash
   cp .env.example .env
   php artisan key:generate
   ```

3. Update database settings in `.env`.

4. Run migrations:

   ```bash
   php artisan migrate
   ```

5. Start the backend server:

   ```bash
   php artisan serve --host=127.0.0.1 --port=8000
   ```

## Quick test user

After running migrations, create a quick test user using seeders and test login:

```bash
cd backend
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

Default seeded user:
- email: test@example.com
- password: password123

Use these credentials from the Flutter app to verify `/auth/login` and `/user` endpoints.

## API

- `POST /api/checkout`
- `GET /api/orders`
