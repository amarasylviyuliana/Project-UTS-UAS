<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SmartSearchController extends Controller
{
    public function search(Request $request): JsonResponse
    {
        $request->validate([
            'keyword_user' => 'required|string|min:1|max:300',
        ]);

        $keywordUser = trim($request->input('keyword_user'));
        $databaseKeyword = $keywordUser;

        try {
            $webhookUrl = $this->resolveWebhookUrl();
            if (!empty($webhookUrl)) {
                $response = Http::timeout(4)
                    ->asJson()
                    ->acceptJson()
                    ->post($webhookUrl, [
                        'keyword_user' => $keywordUser,
                    ]);

                if ($response->successful()) {
                    $aiKeyword = $response->json('kata_kunci_database');
                    if (is_string($aiKeyword) && trim($aiKeyword) !== '') {
                        $databaseKeyword = trim($aiKeyword);
                    }
                } else {
                    Log::error('Smart search webhook returned a non-successful response', [
                        'status' => $response->status(),
                        'body' => $response->body(),
                        'keyword_user' => $keywordUser,
                    ]);
                }
            } else {
                Log::info('Smart search webhook not configured, skipping AI enrichment', ['keyword_user' => $keywordUser]);
            }
        } catch (\Throwable $e) {
            Log::error('Smart search webhook failed', [
                'error' => $e->getMessage(),
                'keyword_user' => $keywordUser,
            ]);
        }

        $products = Product::query()
            ->where(function ($query) use ($databaseKeyword) {
                $query->where('name', 'like', "%{$databaseKeyword}%")
                    ->orWhere('description', 'like', "%{$databaseKeyword}%");
            })
            ->where('is_active', true)
            ->limit(50)
            ->get();

        return response()->json([
            'message' => 'Smart search results',
            'keyword_user' => $keywordUser,
            'search_keyword' => $databaseKeyword,
            'data' => $products,
        ]);
    }

    protected function resolveWebhookUrl(): ?string
    {
        $candidates = array_filter([
            config('services.n8n.webhook_url'),
            env('N8N_WEBHOOK_URL'),
            env('N8N_TELEGRAM_WEBHOOK_URL'),
            env('N8N_URL'),
        ]);

        return is_array($candidates) && !empty($candidates)
            ? (string) reset($candidates)
            : null;
    }
}
