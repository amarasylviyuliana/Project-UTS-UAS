<?php

namespace App\Services;

use Midtrans\Config as MidtransConfig;
use Midtrans\Snap;

class MidtransService
{
    public function __construct()
    {
        MidtransConfig::$serverKey = config('services.midtrans.server_key');
        MidtransConfig::$isProduction = filter_var(config('services.midtrans.is_production', false), FILTER_VALIDATE_BOOLEAN);
        MidtransConfig::$isSanitized = true;
        MidtransConfig::$is3ds = true;

        if (!MidtransConfig::$serverKey) {
            throw new \Exception('MIDTRANS_SERVER_KEY belum dikonfigurasi, silakan isi pada file .env');
        }
    }

    public function createTransaction(string $orderId, float $amount, string $customerName, string $customerEmail): array
    {
        $params = [
            'transaction_details' => [
                'order_id' => $orderId,
                'gross_amount' => (int) round($amount),
            ],
            'customer_details' => [
                'first_name' => $customerName,
                'email' => $customerEmail,
            ],
        ];

        $snapToken = Snap::getSnapToken($params);

        $isProduction = MidtransConfig::$isProduction;
        $baseUrl = $isProduction
            ? 'https://app.midtrans.com/snap/v2/vtweb/'
            : 'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

        return [
            'token' => $snapToken,
            'redirect_url' => $baseUrl . $snapToken,
        ];
    }
}