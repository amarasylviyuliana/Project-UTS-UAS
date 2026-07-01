# Backend Setup & Error Fix Guide

## Issues Identified

### 1. ✅ Migration Error (RESOLVED)
**Error:** `BadMethodCallException: Method Illuminate\Database\Schema\Blueprint::createdAt does not exist`
- **Cause:** Incorrect method call in migration file  
- **Status:** Already fixed in current code (now uses `timestamp('created_at')`)

### 2. ❌ XMLHttpRequest Error (NEEDS FIX)
**Error:** Frontend cannot connect to backend login endpoint
- **Cause:** Backend not properly initialized with database migrations
- **Solution:** Run migrations and start the backend properly

---

## Quick Fix Steps (RUN IN ORDER)

### Step 1: Navigate to Backend Directory
```powershell
cd c:\laragon\www\Project-UTS-UAS\bumdes_jabar\laravel
```

### Step 2: Clear Laravel Cache (Fresh Start)
```powershell
php artisan cache:clear
php artisan config:clear
php artisan view:clear
```

### Step 3: Install/Update Composer Dependencies
```powershell
composer install
```

### Step 4: Generate APP_KEY (if needed)
```powershell
php artisan key:generate
```

### Step 5: Run Migrations (CRITICAL - Fixes Login)
```powershell
php artisan migrate --seed
```

### Step 6: Start Backend Server
```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

**Expected Output:**
```
Laravel development server started: http://127.0.0.1:8000
```

### Step 7: Test Backend Connection
```powershell
# In another PowerShell window, test the API
curl -X POST http://127.0.0.1:8000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"amarasylvi@gmail.com","password":"password"}'
```

---

## Alternative: Use Provided Start Script

If you prefer, run the prepared start script:
```powershell
# From repository root
.\bumdes_jabar\laravel\start_backend.ps1
```

---

## Frontend Configuration

The frontend is configured to connect to: `http://127.0.0.1:8000`

**For Different Environments:**
- **Local Testing on Same Machine:** Use `127.0.0.1:8000` ✅ (Current)
- **Android Emulator:** Change to `10.0.2.2:8000`
- **Real Device:** Use your machine's IP (e.g., `192.168.x.x:8000`)
- **After Production Deploy:** Update to production domain

To change frontend URL, edit:  
📄 `bumdes_frontend/lib/src/config.dart`

---

## Database Connection Details

**Current .env Configuration:**
```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=bumdes_jabar
DB_USERNAME=root
DB_PASSWORD=
```

**Credentials:**
- Database: `bumdes_jabar`
- User: `root`
- Password: (empty)
- Host: `127.0.0.1`
- Port: `3306`

**Access phpMyAdmin:**  
👉 `http://127.0.0.1:8080`

---

## Troubleshooting

### Error: "SQLSTATE[HY000]: General error: 2006 MySQL has gone away"
- ✅ **Fix:** Check if MySQL is running in Laragon
  ```powershell
  # Check MySQL status
  # In Laragon: Click "MySQL" to start/verify it's running
  ```

### Error: "No application encryption key has been specified"
- ✅ **Fix:** Run `php artisan key:generate`

### Error: "Class 'PDO' not found"
- ✅ **Fix:** Ensure PHP has PDO extension (should be in Laragon)

### Migration Stuck or Rolled Back
- ✅ **Fix:** Run fresh migrations:
  ```powershell
  php artisan migrate:fresh --seed
  ```
  ⚠️ **WARNING:** This deletes all data!

---

## Success Indicators

✅ Backend is working if:
1. `php artisan serve` shows: "Laravel development server started: http://127.0.0.1:8000"
2. API responds to login request (even if credentials wrong)
3. No "XMLHttpRequest error" in Flutter app after login

✅ Database is working if:
1. Migrations run without errors
2. phpMyAdmin shows tables in `bumdes_jabar` database
3. Login returns proper error message (not connection error)

---

## Next Steps

1. Follow the **Quick Fix Steps** above (all 7 steps)
2. Test backend with provided curl command
3. Check Flutter app login - should work or show proper error message
4. Monitor console for any new errors

---

*Last Updated: 2026-06-12*
*For Docker-based deployment, refer to `docker-compose.yml` and update DB_HOST to `db`*
