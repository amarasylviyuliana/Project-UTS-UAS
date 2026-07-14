<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiSearchService
{
    protected string $apiKey;
    protected string $model = 'gemini-2.5-flash';

    public function __construct()
    {
        $this->apiKey = config('services.gemini.api_key');

        if (!$this->apiKey) {
            throw new \Exception('GEMINI_API_KEY belum dikonfigurasi, silakan isi pada file .env');
        }
    }

    /**
     * Ubah query bahasa natural (mis. "makanan pedas Garut")
     * menjadi kriteria pencarian terstruktur (JSON).
     *
     * Ini adalah lapisan "pemahaman bahasa" AI. Hasilnya TIDAK dipakai
     * untuk query LIKE ke database (seperti versi lama), melainkan dikirim
     * ke Algolia sebagai kombinasi teks pencarian + facetFilters, supaya
     * pencarian atributnya (misal "pedas") tetap match walau kata itu
     * tidak tertulis di judul produk — karena "tags" adalah atribut
     * tersendiri di index Algolia, bukan cuma substring dari nama produk.
     *
     * Return contoh untuk "makanan pedas Garut":
     * [
     *   'keywords' => ['makanan'],
     *   'category' => 'Kuliner Desa',
     *   'tags' => ['pedas'],
     *   'region' => 'Garut',
     *   'min_price' => null,
     *   'max_price' => null,
     * ]
     */
    public function extractSearchCriteria(string $userQuery): array
    {
        $prompt = <<<PROMPT
Kamu adalah asisten yang mengubah pencarian produk berbahasa natural, termasuk bahasa tidak baku/kasual Indonesia seperti "gak", "nggak", "murce", "nih", dan "dong", menjadi kriteria pencarian terstruktur dalam format JSON, untuk marketplace produk BUMDes (desa) di Jawa Barat.

Pertanyaan pengguna: "{$userQuery}"

Kembalikan HANYA JSON valid (tanpa markdown, tanpa penjelasan tambahan) dengan struktur persis seperti ini:
{
  "keywords": ["kata", "kunci", "relevan"],
  "category": "kategori produk jika disebutkan atau null",
  "tags": ["atribut", "rasa", "atau", "sifat", "produk"],
  "region": "nama kabupaten/kota/kecamatan/desa jika disebutkan atau null",
  "min_price": angka atau null,
  "max_price": angka atau null
}

Gunakan logika ini:
- Jika pengguna meminta sesuatu seperti "termurah", "mahal", "terlaris", atau "produk sehat", jangan letakkan kata itu di "keywords"; itu adalah niat atau filter.
- "keywords" harus fokus pada jenis produk atau kategori, seperti "sepatu", "susu", "kerajinan", "jatim".
- "tags" harus memuat atribut / sifat seperti "sehat", "organik", "pedas", "manis", "kerajinan tangan".
- Jika pengguna menanyakan "termurah" atau "mahal" tanpa menyebut jenis produk, biarkan "keywords" kosong pada JSON dan serahkan urutan/pemfilteran harga kepada backend.

Aturan:
- "keywords" berisi kata-kata inti berupa JENIS barang/jasa yang dicari (mis. "makanan", "sepatu", "kerajinan"), tanpa kata seperti "murah", "mahal", "buat", "untuk", dan tanpa atribut rasa/sifat (itu masuk ke "tags").
- "category" isi null kalau tidak jelas kategorinya. Contoh kategori yang ada: "Pertanian & Perkebunan", "Kerajinan Tangan", "Kuliner Desa", "Jasa Lokal", "Peternakan", "Pariwisata".
- "tags" berisi atribut/sifat/rasa produk yang disebutkan pengguna walau TIDAK akan tertulis persis di judul produk, contoh: "pedas", "manis", "gurih", "asin", "organik", "handmade", "vegan", "pedas level tinggi". Kosongkan array kalau tidak ada atribut yang disebut.
- "region" isi nama daerah (kabupaten/kota/kecamatan/desa) kalau pengguna menyebut lokasi asal produk, mis. "Garut", "Ciwidey", "Pangalengan". Isi null kalau tidak disebutkan.
- "min_price"/"max_price" isi angka rupiah kalau pengguna menyebut rentang harga (misal "di bawah 100rb" => max_price: 100000). Kalau tidak disebutkan, isi null.
- Jangan menambahkan properti lain selain enam itu.
PROMPT;

        $response = Http::timeout(15)->post(
            "https://generativelanguage.googleapis.com/v1beta/models/{$this->model}:generateContent?key={$this->apiKey}",
            [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $prompt],
                        ],
                    ],
                ],
                'generationConfig' => [
                    'temperature' => 0.2,
                    'responseMimeType' => 'application/json',
                ],
            ]
        );

        if ($response->failed()) {
            Log::error('Gemini API request failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            throw new \Exception('Gagal menghubungi layanan AI pencarian.');
        }

        $data = $response->json();
        $text = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;

        if (!$text) {
            Log::error('Gemini API response tidak sesuai format', ['response' => $data]);
            throw new \Exception('Respons AI tidak dapat diproses.');
        }

        $criteria = json_decode($text, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($criteria)) {
            Log::error('Gagal parse JSON dari Gemini', ['raw_text' => $text]);
            // Fallback: pakai query asli sebagai keyword tunggal supaya pencarian tetap jalan
            return $this->fallbackCriteria($userQuery);
        }

        return [
            'keywords' => $criteria['keywords'] ?? [$userQuery],
            'category' => $criteria['category'] ?? null,
            'tags' => $criteria['tags'] ?? [],
            'region' => $criteria['region'] ?? null,
            'min_price' => $criteria['min_price'] ?? null,
            'max_price' => $criteria['max_price'] ?? null,
        ];
    }

    /**
     * Dipakai kalau Gemini gagal total (API down/quota habis/dsb).
     * Pencarian tetap jalan lewat Algolia pakai query mentah, hanya saja
     * tanpa pemahaman atribut/daerah yang presisi.
     */
    public function fallbackCriteria(string $userQuery): array
    {
        return [
            'keywords' => $this->buildFallbackKeywords($userQuery),
            'category' => null,
            'tags' => [],
            'region' => null,
            'min_price' => null,
            'max_price' => null,
        ];
    }

    protected function buildFallbackKeywords(string $userQuery): array
    {
        $parts = preg_split('/[^\p{L}\p{N}]+/u', $userQuery, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $stopWords = [
            'di', 'ke', 'dari', 'untuk', 'dengan', 'yang', 'dan', 'atau',
            'buat', 'mau', 'ingin', 'cari', 'teh', 'kamu', 'saya', 'sedang',
            'ini', 'itu', 'ada', 'lebih', 'kurang', 'sekitar', 'paling',
        ];

        return array_values(array_filter(array_map(function ($part) use ($stopWords) {
            $word = mb_strtolower(trim($part));
            if ($word === '' || mb_strlen($word) < 2) {
                return null;
            }
            if (in_array($word, $stopWords, true)) {
                return null;
            }
            return $word;
        }, $parts)));
    }
}