<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\AlgoliaService;
use App\Services\GeminiSearchService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

/**
 * Fitur pencarian AI, sekarang dua lapis:
 *
 * 1. GeminiSearchService  -> "pemahaman bahasa": ubah query natural
 *    ("makanan pedas Garut") jadi kriteria terstruktur (keywords, tags,
 *    category, region, harga).
 * 2. AlgoliaService       -> "mesin pencarian": eksekusi pencarian yang
 *    sebenarnya ke Algolia (typo-tolerant, hasil dirangking otomatis),
 *    dengan facetFilters presisi dari hasil ekstraksi Gemini.
 *
 * Kenapa "pedas" tetap ketemu walau tidak tertulis di judul produk?
 * Karena atribut itu disimpan terpisah di kolom `tags` produk (mis.
 * ["pedas", "khas garut"]), yang di index Algolia didaftarkan sebagai
 * searchable attribute + facet (lihat AlgoliaService::pushSettings()).
 * Jadi walau nama produknya cuma "Sambal Oncom Bakar Cibiuk", ia tetap
 * cocok untuk query "pedas" karena atributnya ada di data, bukan di judul.
 */
class ProductAISearchController extends Controller
{
    public function search(Request $request): JsonResponse
    {
        $request->validate([
            'query' => 'required|string|min:2|max:200',
        ]);

        $userQuery = $request->input('query');
        $normalizedQuery = $this->normalizeUserQuery($userQuery);
        $criteria = [];

        try {
            $gemini = new GeminiSearchService();
            $criteria = $gemini->extractSearchCriteria($normalizedQuery);
        } catch (\Throwable $e) {
            Log::warning('AI product search: Gemini tidak tersedia, fallback ke query mentah', [
                'error' => $e->getMessage(),
                'query' => $userQuery,
            ]);
            $criteria = [
                'keywords' => [$userQuery],
                'category' => null,
                'tags' => [],
                'region' => null,
                'min_price' => null,
                'max_price' => null,
            ];
        }

        $criteria = $this->enrichCriteria($criteria, $normalizedQuery);

        $algolia = new AlgoliaService();

        if ($algolia->isConfigured()) {
            try {
                return $this->searchViaAlgolia($algolia, $userQuery, $criteria);
            } catch (\Throwable $e) {
                Log::error('AI product search: Algolia gagal, fallback ke database', ['error' => $e->getMessage()]);
                // lanjut ke fallback DB di bawah
            }
        }

        return $this->searchViaDatabase($userQuery, $criteria);
    }

    private function enrichCriteria(array $criteria, string $userQuery): array
    {
        $keywords = array_filter(array_map(fn ($item) => trim((string) $item), $criteria['keywords'] ?? []));
        if (empty($keywords)) {
            $keywords = $this->splitSearchPhrase($userQuery);
        } else {
            $expanded = [];
            foreach ($keywords as $keyword) {
                if (mb_stripos($keyword, ' ') !== false) {
                    $expanded = array_merge($expanded, $this->splitSearchPhrase($keyword));
                } else {
                    $expanded[] = $keyword;
                }
            }
            $keywords = array_values(array_unique(array_filter($expanded)));
        }

        $tags = array_filter(array_map(fn ($item) => trim((string) $item), $criteria['tags'] ?? []));
        $tagMap = [
            'sehat' => ['segar', 'organik', 'alami', 'bergizi'],
            'makanan' => ['segar', 'organik'],
            'sayur' => ['segar', 'organik'],
            'buah' => ['segar', 'organik'],
            'diet' => ['rendah gula', 'segar', 'organik'],
        ];

        foreach ($keywords as $keyword) {
            $lower = mb_strtolower($keyword);
            if (isset($tagMap[$lower])) {
                foreach ($tagMap[$lower] as $extraTag) {
                    if (!in_array($extraTag, $tags, true)) {
                        $tags[] = $extraTag;
                    }
                }
            }
        }

        $sort = $criteria['sort'] ?? $this->deriveSortFromQuery($userQuery);
        $priceRange = $this->derivePriceRangeFromQuery($userQuery);

        if ($criteria['min_price'] === null) {
            $criteria['min_price'] = $priceRange['min'];
        }
        if ($criteria['max_price'] === null) {
            $criteria['max_price'] = $priceRange['max'];
        }

        foreach ($this->deriveHealthyTags($userQuery) as $healthyTag) {
            if (!in_array($healthyTag, $tags, true)) {
                $tags[] = $healthyTag;
            }
        }

        if (empty($criteria['category']) && count(array_filter($keywords, fn ($k) => preg_match('/\b(?:sayur|buah|makanan|jajanan|kuliner|daging|ikan)\b/i', $k))) > 0) {
            $criteria['category'] = $criteria['category'] ?? null;
        }

        return [
            'keywords' => array_values(array_filter($keywords)),
            'category' => $criteria['category'] ?? null,
            'tags' => array_values(array_filter(array_unique($tags))),
            'region' => $criteria['region'] ?? null,
            'min_price' => $criteria['min_price'] ?? null,
            'max_price' => $criteria['max_price'] ?? null,
            'sort' => $sort,
        ];
    }

    private function splitSearchPhrase(string $phrase): array
    {
        $parts = preg_split('/[^\p{L}\p{N}]+/u', $phrase, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $stopWords = [
            'di', 'ke', 'dari', 'untuk', 'dengan', 'yang', 'dan', 'atau',
            'buat', 'mau', 'ingin', 'cari', 'carikan', 'rekomendasi', 'rekomendasikan', 'rekomendasiin', 'sarankan', 'saran',
            'teh', 'kamu', 'saya', 'sedang', 'ini', 'itu', 'ada', 'lebih', 'kurang', 'sekitar', 'paling',
            'sebuah', 'seorang', 'satu', 'dua', 'tiga',
            'dong', 'deh', 'nih', 'sih', 'ya', 'yah', 'kak', 'mas', 'mbak',
            'gak', 'ga', 'nggak', 'enggak', 'aja', 'banget', 'juga', 'oke', 'ok', 'sip',
            'harga', 'termurah', 'mahal', 'terlaris', 'sehat', 'organik', 'diet', 'produk',
        ];

        return array_values(array_filter(array_map(function ($part) use ($stopWords) {
            $word = mb_strtolower(trim($part));
            if ($word === '' || mb_strlen($word) < 2 || in_array($word, $stopWords, true)) {
                return null;
            }
            return $word;
        }, $parts)));
    }

    private function normalizeUserQuery(string $query): string
    {
        $replacements = [
            '/\bgak\b/i' => 'tidak',
            '/\bga\b/i' => 'tidak',
            '/\bnggak\b/i' => 'tidak',
            '/\benggak\b/i' => 'tidak',
            '/\bmurce\b/i' => 'murah',
            '/\bbanget\b/i' => '',
            '/\bdong\b/i' => '',
            '/\bdeh\b/i' => '',
            '/\bnih\b/i' => '',
            '/\bsih\b/i' => '',
            '/\bya\b/i' => '',
            '/\byah\b/i' => '',
            '/\bkak\b/i' => '',
            '/\bmas\b/i' => '',
            '/\bmbak\b/i' => '',
            '/\baja\b/i' => '',
            '/\boke\b/i' => '',
            '/\bok\b/i' => '',
            '/\bsip\b/i' => '',
            '/\brekomendasi(?:kan|in)?\b/i' => '',
            '/\bcar[iy]a?n?\b/i' => '',
            '/\bsarankan?\b/i' => '',
        ];

        $cleaned = preg_replace(array_keys($replacements), array_values($replacements), $query);
        return trim(preg_replace('/\s+/', ' ', $cleaned ?? $query));
    }

    private function deriveSortFromQuery(string $query): ?string
    {
        if (preg_match('/\b(?:terlaris|paling laris|terjual banyak|best seller|best-selling|best seller|best seller)\b/i', $query)) {
            return 'best_selling';
        }
        if (preg_match('/\b(?:harga termurah|termurah|paling murah|murah banget|murah|murce)\b/i', $query)) {
            return 'price_asc';
        }
        if (preg_match('/\b(?:harga mahal|mahal|paling mahal)\b/i', $query)) {
            return 'price_desc';
        }

        return null;
    }

    private function derivePriceRangeFromQuery(string $query): array
    {
        $normalized = mb_strtolower($query);
        $normalized = preg_replace('/[\s\.,]+/', ' ', $normalized);

        $range = ['min' => null, 'max' => null];

        if (preg_match('/\b(?:antara|dari)\s*([0-9]+(?:[.,][0-9]+)?(?:k|rb|ribu)?)\s*(?:dan|sampai|sd|-)\s*([0-9]+(?:[.,][0-9]+)?(?:k|rb|ribu)?)\b/i', $query, $matches)) {
            $range['min'] = $this->parsePriceAmount($matches[1]);
            $range['max'] = $this->parsePriceAmount($matches[2]);
            return $range;
        }

        if (preg_match('/\b(?:di bawah|kurang dari|maks(?:imum)?|maks|min|max|<=?)\s*([0-9]+(?:[.,][0-9]+)?(?:k|rb|ribu)?)\b/i', $query, $matches)) {
            $range['max'] = $this->parsePriceAmount($matches[1]);
        }

        if (preg_match('/\b(?:di atas|lebih dari|mulai|minimal|>=?)\s*([0-9]+(?:[.,][0-9]+)?(?:k|rb|ribu)?)\b/i', $query, $matches)) {
            $range['min'] = $this->parsePriceAmount($matches[1]);
        }

        return $range;
    }

    private function parsePriceAmount(string $token): ?int
    {
        $text = mb_strtolower(trim($token));
        $isThousands = preg_match('/(rb|ribu|k)$/i', $text) === 1;
        $number = preg_replace('/[^0-9.,]/', '', $text);
        if ($number === '') {
            return null;
        }
        $number = str_replace(',', '.', $number);
        $value = (float) $number;
        if ($isThousands) {
            $value *= 1000;
        }
        return (int) round($value);
    }

    private function deriveHealthyTags(string $query): array
    {
        if (!preg_match('/\b(?:sehat|makanan sehat|produk sehat|diet|organik|rendah gula|rendah garam)\b/i', $query)) {
            return [];
        }

        return ['sehat', 'organik', 'segar'];
    }

    private function quoteFacetValue(string $value): string
    {
        $escaped = str_replace('"', '\\"', $value);
        if (preg_match('/[\s:]/', $escaped)) {
            return '"' . $escaped . '"';
        }
        return $escaped;
    }

    /**
     * Jalur utama: Algolia sebagai mesin pencarian.
     */
    private function searchViaAlgolia(AlgoliaService $algolia, string $userQuery, array $criteria): JsonResponse
    {
        // Teks yang dikirim ke Algolia untuk relevansi/typo-tolerance:
        // pakai keywords/tags terstruktur dari AI, bukan seluruh kalimat
        // mentah yang bisa berisi kata-kata seperti "termurah" atau
        // "rekomendasi" yang tidak ada di judul produk.
        $searchTextParts = array_filter(array_merge(
            $criteria['keywords'] ?? [],
            $criteria['tags'] ?? []
        ));
        $searchText = implode(' ', array_unique($searchTextParts));

        // Jika AI hanya mengenali niat urut atau filter umum (mis. "termurah",
        // "terlaris", "sehat") tapi tidak berhasil mengekstrak kata jenis
        // produk, serahkan ke Algolia sebagai query kosong agar pencarian
        // tetap menampilkan semua produk yang cocok menurut facet/numeric filter.
        if ($searchText === '') {
            $searchText = '';
        }

        $facetFilters = [];

        if (!empty($criteria['category'])) {
            $facetFilters[] = ["category_name:{$this->quoteFacetValue($criteria['category'])}"];
        }

        if (!empty($criteria['tags'])) {
            // OR antar tag (produk cocok kalau punya salah satu tag ini)
            $facetFilters[] = array_map(
                fn($tag) => "tags:{$this->quoteFacetValue($tag)}",
                $criteria['tags']
            );
        }

        if (!empty($criteria['region'])) {
            $facetFilters[] = ["store_region:{$this->quoteFacetValue($criteria['region'])}"];
        }

        $numericFilters = [];
        if (!empty($criteria['min_price'])) {
            $numericFilters[] = "price>={$criteria['min_price']}";
        }
        if (!empty($criteria['max_price'])) {
            $numericFilters[] = "price<={$criteria['max_price']}";
        }

        $result = $algolia->search($searchText, $facetFilters, $numericFilters);
        $hits = $result['hits'] ?? [];

        if (empty($hits) && ($result['nbHits'] ?? 0) === 0) {
            Log::warning('AI product search: Algolia tidak menemukan hasil, fallback ke database', [
                'query' => $userQuery,
                'criteria' => $criteria,
            ]);

            return $this->searchViaDatabase($userQuery, $criteria);
        }

        // Ambil objectID (id produk) sesuai urutan rangking dari Algolia,
        // lalu tarik data lengkap & relasinya dari DB (biar konsisten
        // dengan endpoint produk lain + selalu fresh terhadap stok/status).
        $orderedIds = array_map(fn($hit) => (int) $hit['objectID'], $hits);

        $products = collect();
        if (!empty($orderedIds)) {
            $query = Product::query()
                ->with('category')
                ->whereIn('id', $orderedIds)
                ->where('is_active', true);

            if (($criteria['sort'] ?? null) === 'best_selling') {
                $query->withSum('orderItems as total_sold', 'quantity');
            }

            $productsById = $query->get()->keyBy('id');

            $products = collect($orderedIds)
                ->map(fn($id) => $productsById->get($id))
                ->filter()
                ->values();

            if (!empty($criteria['sort'])) {
                switch ($criteria['sort']) {
                    case 'price_asc':
                        $products = $products->sortBy('price')->values();
                        break;
                    case 'price_desc':
                        $products = $products->sortByDesc('price')->values();
                        break;
                    case 'best_selling':
                        $products = $products->sortByDesc('total_sold')->values();
                        break;
                }
            }
        }

        return response()->json([
            'message' => 'Hasil pencarian AI (Algolia)',
            'query' => $userQuery,
            'engine' => 'algolia',
            'interpreted_criteria' => $criteria,
            'count' => $products->count(),
            'data' => $products,
        ]);
    }

    /**
     * Jalur cadangan: dipakai kalau Algolia belum dikonfigurasi (mis. saat
     * development lokal tanpa API key) atau sedang bermasalah, supaya
     * fitur pencarian tetap berfungsi (tanpa keunggulan typo-tolerance &
     * ranking Algolia).
     */
    private function searchViaDatabase(string $userQuery, array $criteria): JsonResponse
    {
        try {
            $keywordsAndTags = array_filter(array_merge(
                $criteria['keywords'] ?? [],
                $criteria['tags'] ?? []
            ));

            $query = Product::query()
                ->with('category', 'store')
                ->when(($criteria['sort'] ?? null) === 'best_selling', function ($q) {
                    $q->withSum('orderItems as total_sold', 'quantity');
                })
                ->when(!empty($keywordsAndTags), function ($q) use ($keywordsAndTags) {
                    $q->where(function ($sub) use ($keywordsAndTags) {
                        foreach ($keywordsAndTags as $keyword) {
                            $keyword = trim($keyword);
                            if ($keyword === '') {
                                continue;
                            }
                            $sub->orWhere('name', 'like', "%{$keyword}%")
                                ->orWhere('description', 'like', "%{$keyword}%")
                                ->orWhereJsonContains('tags', $keyword);
                        }
                    });
                })
                ->when($criteria['category'] ?? null, function ($q) use ($criteria) {
                    $q->whereHas('category', function ($catQuery) use ($criteria) {
                        $catQuery->where('name', 'like', "%{$criteria['category']}%");
                    });
                })
                ->when($criteria['region'] ?? null, function ($q) use ($criteria) {
                    $q->whereHas('store', function ($storeQuery) use ($criteria) {
                        $storeQuery->where('regency', 'like', "%{$criteria['region']}%");
                    });
                })
                ->when($criteria['min_price'] ?? null, function ($q) use ($criteria) {
                    $q->where('price', '>=', $criteria['min_price']);
                })
                ->when($criteria['max_price'] ?? null, function ($q) use ($criteria) {
                    $q->where('price', '<=', $criteria['max_price']);
                })
                ->where('is_active', true)
                ->when(($criteria['sort'] ?? null) === 'price_asc', function ($q) {
                    $q->orderBy('price', 'asc');
                })
                ->when(($criteria['sort'] ?? null) === 'price_desc', function ($q) {
                    $q->orderBy('price', 'desc');
                })
                ->when(($criteria['sort'] ?? null) === 'best_selling', function ($q) {
                    $q->orderByDesc('total_sold');
                })
                ->limit(50);

            $products = $query->get();
        } catch (\Throwable $e) {
            Log::error('AI product search: fallback database gagal', ['error' => $e->getMessage()]);

            return response()->json([
                'message' => 'Terjadi kesalahan saat mencari produk',
                'query' => $userQuery,
                'engine' => 'database-fallback',
                'interpreted_criteria' => $criteria,
                'count' => 0,
                'data' => [],
            ], 500);
        }

        return response()->json([
            'message' => 'Hasil pencarian AI (fallback database, Algolia tidak tersedia)',
            'query' => $userQuery,
            'engine' => 'database-fallback',
            'interpreted_criteria' => $criteria,
            'count' => $products->count(),
            'data' => $products,
        ]);
    }
}
