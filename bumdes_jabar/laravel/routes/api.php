<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\CartController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\MidtransController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\Admin\AdminController;
use App\Http\Controllers\Admin\ApprovalController;
use Illuminate\Support\Facades\Storage;
use App\Http\Controllers\Admin\VerificationController;
use App\Models\Product;
 use App\Http\Controllers\ProductAISearchController;
/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);

// FIX CORS: Image proxy — serve file storage melalui PHP agar CORS header bisa diset
// Browser tidak bisa load langsung dari Railway /storage karena CORS tidak terset di nginx
// Solusi: semua gambar dimuat lewat /api/image/{path} yang di-handle Laravel (CORS header otomatis terset)
Route::get('/image/{path}', function (string $path) {
    // Keamanan: hanya boleh akses file di direktori storage/app/public
    $decodedPath = urldecode($path);
    // Cegah path traversal
    if (str_contains($decodedPath, '..') || str_starts_with($decodedPath, '/')) {
        abort(400, 'Invalid path');
    }
    if (!Storage::disk('public')->exists($decodedPath)) {
        abort(404, 'File not found');
    }
    $file    = Storage::disk('public')->get($decodedPath);
    $mime    = Storage::disk('public')->mimeType($decodedPath);
    return response($file, 200)
        ->header('Content-Type', $mime)
        ->header('Cache-Control', 'public, max-age=86400');
})->where('path', '.*');
Route::get('/email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])->name('verification.verify');

Route::match(['get', 'put', 'delete', 'patch'], '/auth/login', function () {
    return response()->json(['message' => 'Endpoint ini hanya mendukung metode POST.'], 405);
});
Route::match(['get', 'put', 'delete', 'patch'], '/auth/register', function () {
    return response()->json(['message' => 'Endpoint ini hanya mendukung metode POST.'], 405);
});

// Product routes (public)
Route::get('/categories', [ProductController::class, 'getCategories']);
Route::get('/debug/products', function () {
    return response()->json([
        'message' => 'Debug product list',
        'data' => Product::select('id', 'name', 'price', 'is_active', 'stock')->get(),
    ]);
});
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/featured', [ProductController::class, 'getFeatured']);
Route::get('/stores/popular', [ProductController::class, 'getPopularStores']);
Route::get('/products/search', [ProductController::class, 'search']);
Route::get('/products/{id}', [ProductController::class, 'show']);
Route::get('/stores/{store_id}/products', [ProductController::class, 'getByStore']);
Route::get('/products/{productId}/reviews', [ReviewController::class, 'getProductReviews']);

// Midtrans webhook
Route::post('/midtrans/notification', [MidtransController::class, 'notification']);

// CORS Preflight
Route::options('/payments/midtrans/create', function () {
    return response('', 200)
        ->header('Access-Control-Allow-Origin', '*')
        ->header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        ->header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        ->header('Access-Control-Max-Age', '7200');
});

// Protected routes
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/auth/resend-verification', [AuthController::class, 'resendVerificationEmail']);
    Route::get('/auth/me', [AuthController::class, 'me']);

    // Profile
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::put('/profile', [ProfileController::class, 'update']);
    Route::put('/profile/password', [ProfileController::class, 'updatePassword']);

    // Store (seller)
    Route::get('/store', [ProfileController::class, 'getStore']);
    Route::post('/store', [ProfileController::class, 'createOrUpdateStore']);
    Route::put('/store', [ProfileController::class, 'createOrUpdateStore']);

    // Product (seller)
    Route::post('/products', [ProductController::class, 'store']);
    Route::put('/products/{id}', [ProductController::class, 'update']);
    Route::delete('/products/{id}', [ProductController::class, 'destroy']);

Route::post('/products/ai-search', [ProductAISearchController::class, 'search']);

    // Cart
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart/add', [CartController::class, 'add']);
    Route::put('/cart/{cartId}', [CartController::class, 'update']);
    Route::delete('/cart/{cartId}', [CartController::class, 'remove']);
    Route::post('/cart/clear', [CartController::class, 'clear']);

    // Orders
    Route::post('/checkout', [OrderController::class, 'createOrder']);
    Route::post('/orders', [OrderController::class, 'createOrder']);
    Route::get('/orders', [OrderController::class, 'getBuyerOrders']);
    Route::get('/orders/buyer/history', [OrderController::class, 'getBuyerOrders']);
    Route::get('/orders/{id}', [OrderController::class, 'show']);
    Route::get('/seller/orders', [OrderController::class, 'getSellerOrders']);
    Route::put('/orders/{id}/status', [OrderController::class, 'updateStatus']);
    Route::put('/orders/{id}/confirm-receipt', [OrderController::class, 'confirmReceipt']);
    Route::put('/orders/{id}/cancel', [OrderController::class, 'cancelOrder']);

    // Payments
    Route::post('/payments/midtrans/create', [PaymentController::class, 'createMidtransPayment']);
    Route::get('/payments/{orderId}', [PaymentController::class, 'show']);
    Route::post('/payments/{orderId}/upload-proof', [PaymentController::class, 'uploadProof']);
    Route::post('/payments/{orderId}/submit', [PaymentController::class, 'submitPayment']);
    Route::get('/payments/{orderId}/proof', [PaymentController::class, 'getProof']);
    Route::post('/payments/{orderId}/confirm', [PaymentController::class, 'confirmPayment']);
    Route::post('/payments/{orderId}/reject', [PaymentController::class, 'rejectPayment']);

    // Reviews
    Route::post('/reviews', [ReviewController::class, 'store']);
    Route::get('/reviews/my', [ReviewController::class, 'getBuyerReviews']);
    Route::put('/reviews/{reviewId}', [ReviewController::class, 'update']);
    Route::delete('/reviews/{reviewId}', [ReviewController::class, 'destroy']);

    // Reports
    Route::get('/reports/buyer', [ReportController::class, 'buyerReport']);
    Route::get('/reports/store', [ReportController::class, 'storeReport']);
    Route::get('/reports/platform', [ReportController::class, 'platformReport']);

    // =========================================================================
    // ADMIN ROUTES
    // =========================================================================
    Route::middleware('role:Admin')->group(function () {

        // Alias tanpa prefix /admin
        Route::get('/users',              [AdminController::class, 'getAllUsers']);
        Route::post('/users',             [AdminController::class, 'createUser']);
        Route::put('/users/{id}',         [AdminController::class, 'updateUser']);
        Route::delete('/users/{id}',      [AdminController::class, 'deleteUser']);

        Route::get('/stores',             [AdminController::class, 'getAllStores']);
        Route::put('/stores/{id}',        [AdminController::class, 'updateStore']);
        Route::delete('/stores/{id}',     [AdminController::class, 'deleteStore']);

        Route::put('/products/{id}/deactivate', [ProductController::class, 'deactivate']);

        // Route dengan prefix /admin
        Route::prefix('admin')->group(function () {

            Route::get('/dashboard/stats', [AdminController::class, 'getDashboardStats']);

            Route::get('/admins',          [AdminController::class, 'getAllAdmins']);
            Route::get('/admins/{id}',     [AdminController::class, 'getAdminDetail']);
            Route::post('/admins',         [AdminController::class, 'createAdmin']);
            Route::put('/admins/{id}',     [AdminController::class, 'updateAdmin']);

            Route::get('/users',           [AdminController::class, 'getAllUsers']);
            Route::post('/users',          [AdminController::class, 'createUser']);
            Route::put('/users/{id}',      [AdminController::class, 'updateUser']);
            Route::delete('/users/{id}',   [AdminController::class, 'deleteUser']);

            Route::get('/stores',          [AdminController::class, 'getAllStores']);
            Route::put('/stores/{id}',     [AdminController::class, 'updateStore']);
            Route::delete('/stores/{id}',  [AdminController::class, 'deleteStore']);

            Route::get('/products',        [AdminController::class, 'getAllProducts']);
            Route::delete('/products/{id}',[AdminController::class, 'deleteProduct']);
            Route::put('/products/{id}/deactivate', [ProductController::class, 'deactivate']);
            Route::delete('/products/{id}/force',   [ProductController::class, 'adminDelete']);

            Route::get('/orders',              [AdminController::class, 'getAllOrders']);
            Route::get('/orders/{id}',         [AdminController::class, 'getOrderDetail']);
            Route::put('/orders/{id}/status',  [AdminController::class, 'updateOrderStatus']);

            Route::get('/approvals/stats',         [ApprovalController::class, 'getApprovalStats']);
            Route::get('/store-approvals',         [ApprovalController::class, 'getPendingStoreApprovals']);
            Route::get('/store-approvals/{id}',    [ApprovalController::class, 'getStoreApprovalDetail']);
            Route::put('/store-approvals/{id}',    [ApprovalController::class, 'approveStore']);
            Route::get('/product-approvals',       [ApprovalController::class, 'getPendingProductApprovals']);
            Route::get('/product-approvals/{id}',  [ApprovalController::class, 'getProductApprovalDetail']);
            Route::put('/product-approvals/{id}',  [ApprovalController::class, 'approveProduct']);

            Route::get('/verifications',                        [VerificationController::class, 'getPendingVerifications']);
            Route::get('/verifications/{id}',                   [VerificationController::class, 'getVerificationDetail']);
            Route::put('/verifications/{id}',                   [VerificationController::class, 'verifySeller']);
            Route::get('/seller/{userId}/verification-history', [VerificationController::class, 'getSellerVerificationHistory']);

            Route::get('/audit-logs',                 [AdminController::class, 'getAllAuditLogs']);
            Route::get('/audit-logs/admin/{adminId}', [AdminController::class, 'getAdminAuditLogs']);
        });
    });
});