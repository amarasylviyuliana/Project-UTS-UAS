<?php

namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Pembungkus tipis untuk Algolia Search REST API.
 *
 * Kenapa panggil REST API langsung (bukan SDK resmi algolia/algoliasearch-
 * client-php via Composer)? Supaya proyek ini tetap bisa jalan tanpa
 * langkah instalasi tambahan yang butuh akses internet ke Packagist —
 * sama seperti GeminiSearchService yang juga manggil Gemini pakai
 * Illuminate\Support\Facades\Http biasa, bukan SDK Google.
 *
 * Referensi endpoint: https://www.algolia.com/doc/rest-api/search/
 */
class AlgoliaService
{
    protected ?string $appId;
    protected ?string $adminKey;
    protected ?string $searchKey;
    protected string $indexName;

    public function __construct()
    {
        $this->appId = config('services.algolia.app_id');
        $this->adminKey = config('services.algolia.admin_key');
        $this->searchKey = config('services.algolia.search_key');
        $this->indexName = config('services.algolia.products_index', 'bumdes_products');
    }

    public function isConfigured(): bool
    {
        return !empty($this->appId) && !empty($this->adminKey);
    }

    /**
     * Host untuk operasi WRITE (index, hapus, ubah settings).
     * Selalu pakai domain utama {appId}.algolia.net.
     */
    protected function writeBaseUrl(): string
    {
        return "https://{$this->appId}.algolia.net/1/indexes/{$this->indexName}";
    }

    /**
     * Host untuk operasi READ (search). Pakai subdomain -dsn yang
     * dioptimalkan Algolia untuk kecepatan baca + failover otomatis.
     */
    protected function readBaseUrl(): string
    {
        return "https://{$this->appId}-dsn.algolia.net/1/indexes/{$this->indexName}";
    }

    protected function writeHeaders(): array
    {
        return [
            'X-Algolia-Application-Id' => $this->appId,
            'X-Algolia-API-Key' => $this->adminKey,
            'Content-Type' => 'application/json',
        ];
    }

    protected function readHeaders(): array
    {
        return [
            'X-Algolia-Application-Id' => $this->appId,
            // Search key kalau tersedia (idealnya dipakai untuk read-only),
            // fallback ke admin key supaya tetap jalan walau search key
            // belum diisi di .env.
            'X-Algolia-API-Key' => $this->searchKey ?: $this->adminKey,
            'Content-Type' => 'application/json',
        ];
    }

    /**
     * Ubah satu Product Eloquent jadi "record" Algolia.
     *
     * Field 'tags' & 'store_region' inilah kunci supaya query seperti
     * "makanan pedas Garut" bisa ketemu produk walau kata "pedas" tidak
     * ada di judul: keduanya didaftarkan sebagai searchable attribute +
     * facet (lihat AlgoliaReindexCommand::indexSettings()).
     */
    public function toRecord(Product $product): array
    {
        $tags = is_array($product->tags) ? array_values(array_filter($product->tags)) : [];

        return [
            'objectID' => (string) $product->id,
            'product_id' => $product->id,
            'name' => $product->name,
            'description' => $product->description,
            'tags' => $tags,
            'category_id' => $product->category_id,
            'category_name' => $product->category?->name,
            'store_id' => $product->store_id,
            'store_name' => $product->store?->store_name,
            'store_village' => $product->store?->village,
            'store_district' => $product->store?->district,
            'store_region' => $product->store?->regency, // mis. "Garut"
            'price' => (float) $product->price,
            'type' => $product->type,
            'is_active' => (bool) $product->is_active,
        ];
    }

    public function saveProduct(Product $product): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $response = Http::withHeaders($this->writeHeaders())
                ->timeout(10)
                ->put($this->writeBaseUrl() . '/' . $product->id, $this->toRecord($product));

            if ($response->failed()) {
                Log::warning('Algolia saveProduct gagal', [
                    'product_id' => $product->id,
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
                return false;
            }

            return true;
        } catch (\Throwable $e) {
            Log::warning('Algolia saveProduct exception', ['error' => $e->getMessage()]);
            return false;
        }
    }

    /**
     * Index banyak produk sekaligus pakai Batch API (jauh lebih efisien
     * dibanding save satu-satu, dipakai oleh AlgoliaReindexCommand).
     */
    public function saveProducts(iterable $products): int
    {
        if (!$this->isConfigured()) {
            return 0;
        }

        $requests = [];
        foreach ($products as $product) {
            $requests[] = [
                'action' => 'updateObject',
                'body' => $this->toRecord($product),
            ];
        }

        if (empty($requests)) {
            return 0;
        }

        try {
            $response = Http::withHeaders($this->writeHeaders())
                ->timeout(30)
                ->post($this->writeBaseUrl() . '/batch', ['requests' => $requests]);

            if ($response->failed()) {
                Log::error('Algolia batch index gagal', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
                return 0;
            }

            return count($requests);
        } catch (\Throwable $e) {
            Log::error('Algolia batch index exception', ['error' => $e->getMessage()]);
            return 0;
        }
    }

    public function deleteProduct(int $productId): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $response = Http::withHeaders($this->writeHeaders())
                ->timeout(10)
                ->delete($this->writeBaseUrl() . '/' . $productId);

            return $response->successful();
        } catch (\Throwable $e) {
            Log::warning('Algolia deleteProduct exception', ['error' => $e->getMessage()]);
            return false;
        }
    }

    /**
     * Atur "otak" relevansi index: attribute mana yang bisa dicari
     * (searchableAttributes) dan mana yang bisa dipakai sebagai
     * filter/facet (attributesForFaceting).
     *
     * 'tags' & 'store_region' sengaja dimasukkan ke DUA-duanya:
     * - sebagai searchableAttributes -> supaya kata "pedas" atau "garut"
     *   di query bisa "nemu" produk walau tidak ada di judul/deskripsi.
     * - sebagai attributesForFaceting -> supaya backend bisa kirim
     *   facetFilters presisi (tags:pedas, store_region:Garut) begitu
     *   Gemini berhasil mengekstrak atribut itu dari query pengguna.
     */
    public function pushSettings(): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        $settings = [
            'searchableAttributes' => [
                'name',
                'tags',
                'category_name',
                'store_region',
                'description',
                'store_name',
            ],
            'attributesForFaceting' => [
                'searchable(tags)',
                'searchable(category_name)',
                'searchable(store_region)',
                'filterOnly(is_active)',
                'filterOnly(type)',
            ],
            'customRanking' => ['desc(is_active)'],
            'typoTolerance' => true,
            'ignorePlurals' => true,
            'removeStopWords' => ['id', 'en'],
        ];

        try {
            $response = Http::withHeaders($this->writeHeaders())
                ->timeout(15)
                ->put($this->writeBaseUrl() . '/settings', $settings);

            return $response->successful();
        } catch (\Throwable $e) {
            Log::error('Algolia pushSettings exception', ['error' => $e->getMessage()]);
            return false;
        }
    }

    /**
     * Jalankan pencarian ke Algolia.
     *
     * @param string $query          teks pencarian (relevansi + typo-tolerance Algolia)
     * @param array  $facetFilters   mis. [['tags:pedas'], ['store_region:Garut']] (AND antar grup, OR dalam grup)
     * @param array  $numericFilters mis. ['price>=10000', 'price<=50000']
     */
    public function search(string $query, array $facetFilters = [], array $numericFilters = [], int $hitsPerPage = 50): array
    {
        if (!$this->isConfigured()) {
            throw new \Exception('Algolia belum dikonfigurasi (ALGOLIA_APP_ID / ALGOLIA_ADMIN_API_KEY kosong).');
        }

        $params = [
            'query' => $query,
            'filters' => 'is_active:true',
            'hitsPerPage' => $hitsPerPage,
        ];

        if (!empty($facetFilters)) {
            $params['facetFilters'] = $facetFilters;
        }

        if (!empty($numericFilters)) {
            $params['numericFilters'] = $numericFilters;
        }

        $response = Http::withHeaders($this->readHeaders())
            ->timeout(10)
            ->post($this->readBaseUrl() . '/query', $params);

        if ($response->failed()) {
            Log::error('Algolia search gagal', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            throw new \Exception('Gagal menghubungi Algolia.');
        }

        return $response->json();
    }
}
