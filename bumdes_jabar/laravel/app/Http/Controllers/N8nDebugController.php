<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Services\N8nNotificationService;
use Illuminate\Support\Facades\Log;

class N8nDebugController extends Controller
{
    public function test(Request $request, N8nNotificationService $n8n): JsonResponse
    {
        $input = $request->all();

        $payload = empty($input) ? [
            'event' => 'order_created',
            'order_number' => 'ORD-TEST-' . time(),
            'pembeli_telegram_chat_id' => null,
            'seller_telegram_chat_id' => null,
            'item' => 'Test Item',
            'total' => 10000,
        ] : $input;

        try {
            $result = $n8n->debugSend($payload);
            return response()->json(['ok' => true, 'result' => $result]);
        } catch (\Throwable $e) {
            Log::error('N8N debug send error: ' . $e->getMessage());
            return response()->json(['ok' => false, 'error' => $e->getMessage()], 500);
        }
    }
}
