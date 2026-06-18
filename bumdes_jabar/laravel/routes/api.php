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
use App\Http\Controllers\Admin\VerificationController;
use App\Models\Product;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// Handle CORS preflight requests
Route::options('/{any}', function() {
    return response()->json([])
        ->header('Access-Control-Allow-Origin', '*')
        ->header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        ->header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With')
        ->header('Access-Control-Max-Age', '86400');
})->where('any', '.*');

// Public routes (no authentication required)
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::get('/email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])->name('verification.verify');

Route::match(['get', 'put', 'delete', 'patch'], '/auth/login', function () {
    return response()->json([
        'message' => 'Endpoint ini hanya mendukung metode POST. Gunakan POST ke /api/auth/login dengan body JSON yang tepat.',
    ], 405);
});

Route::match(['get', 'put', 'delete', 'patch'], '/auth/register', function () {
    return response()->json([
        'message' => 'Endpoint ini hanya mendukung metode POST. Gunakan POST ke /api/auth/register dengan body JSON yang tepat.',
    ], 405);
});

// Product routes (public)
Route::get('/categories', [ProductController::class, 'getCategories']);
// Debug: list products for quick checks
Route::get('/debug/products', function () {
    return response()->json([
        'message' => 'Debug product list',
        'data' => Product::select('id', 'name', 'price', 'is_active', 'stock')->get(),
    ]);
});
// Public products list endpoint
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/featured', [ProductController::class, 'getFeatured']);
Route::get('/stores/popular', [ProductController::class, 'getPopularStores']);
Route::get('/products/search', [ProductController::class, 'search']);
Route::get('/products/{id}', [ProductController::class, 'show']);
Route::get('/stores/{store_id}/products', [ProductController::class, 'getByStore']);
Route::get('/products/{productId}/reviews', [ReviewController::class, 'getProductReviews']);

// Midtrans notification webhook (public endpoint)
Route::post('/midtrans/notification', [MidtransController::class, 'notification']);

// Xendit webhook endpoint (public endpoint)
Route::post('/payments/webhook', [PaymentController::class, 'webhook']);

// Protected routes (authentication required)
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/auth/resend-verification', [AuthController::class, 'resendVerificationEmail']);
    Route::get('/auth/me', [AuthController::class, 'me']);

    // Profile routes
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::put('/profile', [ProfileController::class, 'update']);
    Route::put('/profile/password', [ProfileController::class, 'updatePassword']);

    // Store routes (seller only)
    Route::get('/store', [ProfileController::class, 'getStore']);
    Route::post('/store', [ProfileController::class, 'createOrUpdateStore']);
    Route::put('/store', [ProfileController::class, 'createOrUpdateStore']);

    // Product routes (seller only)
    Route::post('/products', [ProductController::class, 'store']);
    Route::put('/products/{id}', [ProductController::class, 'update']);
    Route::delete('/products/{id}', [ProductController::class, 'destroy']);

    // Admin product moderation
    Route::middleware('role:Admin')->group(function () {
        Route::put('/admin/products/{id}/deactivate', [ProductController::class, 'deactivate']);
        Route::delete('/admin/products/{id}', [ProductController::class, 'adminDelete']);
    });

    // Cart routes
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart/add', [CartController::class, 'add']);
    Route::put('/cart/{cartId}', [CartController::class, 'update']);
    Route::delete('/cart/{cartId}', [CartController::class, 'remove']);
    Route::post('/cart/clear', [CartController::class, 'clear']);

    // Order routes
    // Compatibility: some frontends call /api/checkout — map it to createOrder
    Route::post('/checkout', [OrderController::class, 'createOrder']);
    Route::post('/orders', [OrderController::class, 'createOrder']);
    Route::get('/orders', [OrderController::class, 'getBuyerOrders']);
    Route::get('/orders/buyer/history', [OrderController::class, 'getBuyerOrders']);
    Route::get('/orders/{id}', [OrderController::class, 'show']);
    Route::get('/seller/orders', [OrderController::class, 'getSellerOrders']);
    Route::put('/orders/{id}/status', [OrderController::class, 'updateStatus']);
    Route::put('/orders/{id}/confirm-receipt', [OrderController::class, 'confirmReceipt']);
    Route::put('/orders/{id}/cancel', [OrderController::class, 'cancelOrder']);

    // Payment routes
    Route::get('/payments/{orderId}', [PaymentController::class, 'show']);
    Route::post('/payments/create', [PaymentController::class, 'createInvoice']);
    Route::post('/payments/{orderId}/upload-proof', [PaymentController::class, 'uploadProof']);
    Route::post('/payments/{orderId}/submit', [PaymentController::class, 'submitPayment']);
    Route::get('/payments/{orderId}/proof', [PaymentController::class, 'getProof']);
    Route::post('/payments/{orderId}/confirm', [PaymentController::class, 'confirmPayment']);
    Route::post('/payments/{orderId}/reject', [PaymentController::class, 'rejectPayment']);

    // Review routes
    Route::post('/reviews', [ReviewController::class, 'store']);
    Route::get('/reviews/my', [ReviewController::class, 'getBuyerReviews']);
    Route::put('/reviews/{reviewId}', [ReviewController::class, 'update']);
    Route::delete('/reviews/{reviewId}', [ReviewController::class, 'destroy']);

    // Report routes
    Route::get('/reports/buyer', [ReportController::class, 'buyerReport']);
    Route::get('/reports/store', [ReportController::class, 'storeReport']);
    Route::get('/reports/platform', [ReportController::class, 'platformReport']);

    // Admin routes (authentication + admin role required)
    Route::middleware('role:Admin')->prefix('admin')->group(function () {
        // Admin management
        Route::get('/admins', [AdminController::class, 'getAllAdmins']);
        Route::get('/admins/{id}', [AdminController::class, 'getAdminDetail']);
        Route::post('/admins', [AdminController::class, 'createAdmin']);
        Route::put('/admins/{id}', [AdminController::class, 'updateAdmin']);
        Route::get('/dashboard/stats', [AdminController::class, 'getDashboardStats']);

        // Approval management
        Route::get('/approvals/stats', [ApprovalController::class, 'getApprovalStats']);

        // Store approvals
        Route::get('/store-approvals', [ApprovalController::class, 'getPendingStoreApprovals']);
        Route::get('/store-approvals/{id}', [ApprovalController::class, 'getStoreApprovalDetail']);
        Route::put('/store-approvals/{id}', [ApprovalController::class, 'approveStore']);

        // Product approvals
        Route::get('/product-approvals', [ApprovalController::class, 'getPendingProductApprovals']);
        Route::get('/product-approvals/{id}', [ApprovalController::class, 'getProductApprovalDetail']);
        Route::put('/product-approvals/{id}', [ApprovalController::class, 'approveProduct']);

        // Seller verification
        Route::get('/verifications', [VerificationController::class, 'getPendingVerifications']);
        Route::get('/verifications/{id}', [VerificationController::class, 'getVerificationDetail']);
        Route::put('/verifications/{id}', [VerificationController::class, 'verifySeller']);
        Route::get('/seller/{userId}/verification-history', [VerificationController::class, 'getSellerVerificationHistory']);

        // Audit logs
        Route::get('/audit-logs', [AdminController::class, 'getAllAuditLogs']);
        Route::get('/audit-logs/admin/{adminId}', [AdminController::class, 'getAdminAuditLogs']);
    });
});
