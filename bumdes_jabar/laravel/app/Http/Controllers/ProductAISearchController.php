<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\GeminiSearchService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

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
        } catch (\Exception $e) {
            \Log::error('AI product search failed', ['error' => $e->getMessage()]);

            // Fallback: kalau AI gagal, tetap coba cari pakai query asli
            $criteria = [
                'keywords' => [$userQuery],
                'category' => null,
                'min_price' => null,
                'max_price' => null,
            ];
        }

        $products = Product::query()
            ->when(!empty($criteria['keywords']), function ($q) use ($criteria) {
                $q->where(function ($sub) use ($criteria) {
                    foreach ($criteria['keywords'] as $keyword) {
                        $keyword = trim($keyword);
                        if ($keyword === '') {
                            continue;
                        }
                        // Sesuaikan nama kolom di bawah ini dengan skema tabel products kamu
                        // (mis. kalau tidak ada kolom 'description', hapus baris orWhere itu)
                        $sub->orWhere('name', 'like', "%{$keyword}%")
                            ->orWhere('description', 'like', "%{$keyword}%");
                    }
                });
            })
            ->when($criteria['category'], function ($q) use ($criteria) {
                // Sesuaikan nama kolom kategori dengan skema kamu
                // (mis. 'category' string, atau relasi 'category.name')
                $q->where('category', 'like', "%{$criteria['category']}%");
            })
            ->when($criteria['min_price'], function ($q) use ($criteria) {
                $q->where('price', '>=', $criteria['min_price']);
            })
            ->when($criteria['max_price'], function ($q) use ($criteria) {
                $q->where('price', '<=', $criteria['max_price']);
            })
            ->limit(50)
            ->get();

        return response()->json([
            'message' => 'Hasil pencarian AI',
            'query' => $userQuery,
            'interpreted_criteria' => $criteria,
            'count' => $products->count(),
            'data' => $products,
        ]);
    }
}