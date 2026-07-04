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
     * Ubah query bahasa natural (mis. "sepatu murah buat lari")
     * menjadi kriteria pencarian terstruktur (JSON).
     *
     * Return contoh:
     * [
     *   'keywords' => ['sepatu', 'lari'],
     *   'category' => 'olahraga',
     *   'min_price' => null,
     *   'max_price' => 200000,
     * ]
     */
    public function extractSearchCriteria(string $userQuery): array
    {
        $prompt = <<<PROMPT
Kamu adalah asisten yang mengubah pencarian produk berbahasa natural menjadi kriteria pencarian terstruktur dalam format JSON.

Pertanyaan pengguna: "{$userQuery}"

Kembalikan HANYA JSON valid (tanpa markdown, tanpa penjelasan tambahan) dengan struktur persis seperti ini:
{
  "keywords": ["kata", "kunci", "relevan"],
  "category": "kategori produk jika disebutkan atau null",
  "min_price": angka atau null,
  "max_price": angka atau null
}

Aturan:
- "keywords" berisi kata-kata inti yang menggambarkan produk yang dicari (nama barang, jenis, fungsi), tanpa kata seperti "murah", "mahal", "buat", "untuk".
- "category" isi null kalau tidak jelas kategorinya.
- "min_price"/"max_price" isi angka rupiah kalau pengguna menyebut rentang harga (misal "di bawah 100rb" => max_price: 100000). Kalau tidak disebutkan, isi null.
- Jangan menambahkan properti lain selain empat itu.
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
            return [
                'keywords' => [$userQuery],
                'category' => null,
                'min_price' => null,
                'max_price' => null,
            ];
        }

        return [
            'keywords' => $criteria['keywords'] ?? [$userQuery],
            'category' => $criteria['category'] ?? null,
            'min_price' => $criteria['min_price'] ?? null,
            'max_price' => $criteria['max_price'] ?? null,
        ];
    }
}