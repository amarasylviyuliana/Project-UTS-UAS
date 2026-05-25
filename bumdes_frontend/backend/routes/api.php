<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CheckoutController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\ProductController;

Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
Route::get('/user', [AuthController::class, 'me'])->middleware('auth:sanctum');
Route::get('/products', [ProductController::class, 'index']);

// Handle CORS preflight for API routes
Route::options('/{any}', function () {
    return response('', 200)
        ->header('Access-Control-Allow-Origin', '*')
        ->header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
        ->header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
})->where('any', '.*');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/checkout', [CheckoutController::class, 'checkout']);
    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders/{order}/payment-proof', [OrderController::class, 'uploadPaymentProof']);
});
