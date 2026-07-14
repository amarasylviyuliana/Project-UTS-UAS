<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Support\Facades\Http;

class N8nNotificationFallbackTest extends TestCase
{
    public function test_fallback_to_telegram_on_n8n_failure()
    {
        // Ensure config/env values used by the service are present
        $this->app['config']->set('services.n8n.webhook_url', 'https://example-n8n.test/webhook');
        $this->app['config']->set('services.n8n.group_chat_id', '-1001234567890');
        putenv('TELEGRAM_BOT_TOKEN=8993863404:AAHDvEroqtOpMX15DiI0G7M5ZLEuXl_gcSc');

        // Fake HTTP calls: n8n webhook returns 500, Telegram API returns success
        Http::fake([
            'https://example-n8n.test/*' => Http::response(null, 500),
            'https://api.telegram.org/*' => Http::response(['ok' => true], 200),
        ]);

        $service = $this->app->make(\App\Services\N8nNotificationService::class);

        $payload = [
            'event' => 'order_created',
            'order_number' => 'TST-123',
            'pembeli_telegram_chat_id' => null,
            'seller_telegram_chat_id' => null,
            'item' => 'Test Item',
            'total' => 10000,
        ];

        $result = $service->debugSend($payload);

        $this->assertArrayHasKey('telegram_fallback', $result);
        $this->assertTrue($result['telegram_fallback']['ok'] ?? false, 'Expected Telegram fallback to succeed');
    }
}
