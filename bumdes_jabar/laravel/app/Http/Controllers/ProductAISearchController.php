<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\GeminiSearchService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class ProductAISearchController extends Controller
{
    public function search(Request $request): JsonResponse
    {
        $request->validate([
            'query' => 'required|string|min:2|max:200',
        ]);

        $userQuery = $request->input('query');

        try {
            $gemini = new GeminiSearchService();
            $criteria = $gemini->extractSearchCriteria($userQuery);
        } catch (\Throwable $e) {
            Log::error('AI product search failed', ['error' => $e->getMessage()]);

            // Fallback: kalau AI gagal, tetap coba cari pakai query asli
            $criteria = [
                'keywords' => [$userQuery],
                'category' => null,
                'min_price' => null,
                'max_price' => null,
            ];
        }

        try {
            $products = Product::query()
                ->with('category') // biar relasi kategori ikut dikirim ke frontend
                ->when(!empty($criteria['keywords']), function ($q) use ($criteria) {
                    $q->where(function ($sub) use ($criteria) {
                        foreach ($criteria['keywords'] as $keyword) {
                            $keyword = trim($keyword);
                            if ($keyword === '') {
                                continue;
                            }
                            $sub->orWhere('name', 'like', "%{$keyword}%")
                                ->orWhere('description', 'like', "%{$keyword}%");
                        }
                    });
                })
                ->when($criteria['category'], function ($q) use ($criteria) {
                    // products.category_id -> categories.name (bukan kolom 'category' langsung)
                    $q->whereHas('category', function ($catQuery) use ($criteria) {
                        $catQuery->where('name', 'like', "%{$criteria['category']}%");
                    });
                })
                ->when($criteria['min_price'], function ($q) use ($criteria) {
                    $q->where('price', '>=', $criteria['min_price']);
                })
                ->when($criteria['max_price'], function ($q) use ($criteria) {
                    $q->where('price', '<=', $criteria['max_price']);
                })
                ->where('is_active', true)
                ->limit(50)
                ->get();
        } catch (\Throwable $e) {
            Log::error('AI product search query failed', ['error' => $e->getMessage()]);

            return response()->json([
                'message' => 'Terjadi kesalahan saat mencari produk',
                'query' => $userQuery,
                'interpreted_criteria' => $criteria,
                'count' => 0,
                'data' => [],
            ], 500);
        }

        return response()->json([
            'message' => 'Hasil pencarian AI',
            'query' => $userQuery,
            'interpreted_criteria' => $criteria,
            'count' => $products->count(),
            'data' => $products,
        ]);
    }
}