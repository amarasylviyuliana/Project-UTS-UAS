<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        $products = Product::orderBy('name')->get();

        return response()->json([
            'message' => 'Daftar produk berhasil diambil.',
            'data' => $products,
        ], 200)
            ->header('Access-Control-Allow-Origin', '*')
            ->header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    }
}
