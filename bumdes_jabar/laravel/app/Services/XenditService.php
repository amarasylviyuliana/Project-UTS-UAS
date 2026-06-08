<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Xendit\Invoice\CreateInvoiceRequest;
use Xendit\Invoice\InvoiceApi;

class XenditService
{
    public function __construct()
    {
        $secretKey = env('XENDIT_SECRET_KEY');
        if (!$secretKey) {
            throw new \RuntimeException('Xendit belum dikonfigurasi, silakan isi API Key pada file .env');
        }

        if (!$this->isValidSecretKey($secretKey)) {
            throw new \RuntimeException('Xendit secret key tidak valid. Pastikan XENDIT_SECRET_KEY berisi secret key Xendit yang benar.');
        }

        // Prefer SDK if present, otherwise we'll use direct HTTP calls
        if (class_exists(InvoiceApi::class)) {
            $this->useSdk = true;
            $this->secretKey = $secretKey;
        } else {
            Log::warning('Xendit SDK tidak ditemukan, menggunakan fallback HTTP client');
            $this->useSdk = false;
            $this->secretKey = $secretKey;
        }
    }

    private function isValidSecretKey(string $secretKey): bool
    {
        return str_starts_with($secretKey, 'xnd_secret_')
            || str_starts_with($secretKey, 'xnd_development_')
            || str_starts_with($secretKey, 'xnd_production_');
    }

    public function createInvoice(
        string $externalId,
        float $amount,
        string $customerName,
        string $customerEmail,
        array $paymentMethods = [],
        ?string $successRedirectUrl = null,
        ?string $failureRedirectUrl = null
    ): array {
        $params = [
            'external_id' => $externalId,
            'amount' => $amount,
            'description' => "Pembayaran pesanan untuk {$customerName}",
            'payer_email' => $customerEmail,
            'payment_methods' => $paymentMethods,
            'should_send_email' => false,
        ];

        if ($successRedirectUrl) {
            $params['success_redirect_url'] = $successRedirectUrl;
        }
        if ($failureRedirectUrl) {
            $params['failure_redirect_url'] = $failureRedirectUrl;
        }

        if (!empty($this->useSdk)) {
            $api = new InvoiceApi();
            $api->setApiKey($this->secretKey);
            $request = new CreateInvoiceRequest($params);
            $invoice = $api->createInvoice($request);
            return json_decode(json_encode($invoice), true);
        }

        // Fallback: call Xendit HTTP API directly using curl
        $url = 'https://api.xendit.co/v2/invoices';
        $payload = json_encode($params);
        Log::info('Xendit payload (fallback)', ['url' => $url, 'payload' => $params]);

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, $this->secretKey . ':');
        curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
        ]);

        $resp = curl_exec($ch);
        $err = curl_error($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($err) {
            Log::error('Xendit HTTP request failed', ['error' => $err]);
            throw new \RuntimeException('Xendit request failed: ' . $err);
        }

        $decoded = json_decode($resp, true);
        Log::info('Xendit response (fallback)', ['status' => $code, 'body' => $decoded]);

        if ($code < 200 || $code >= 300) {
            $msg = is_array($decoded) && isset($decoded['message']) ? $decoded['message'] : $resp;
            throw new \RuntimeException('Xendit returned error: ' . $msg);
        }

        return $decoded ?? [];
    }

    public function getInvoice(string $invoiceId): array
    {
        if (!empty($this->useSdk)) {
            $api = new InvoiceApi();
            $api->setApiKey($this->secretKey);
            $invoice = $api->getInvoiceById($invoiceId);
            return json_decode(json_encode($invoice), true);
        }

        $url = 'https://api.xendit.co/v2/invoices/' . rawurlencode($invoiceId);
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_USERPWD, $this->secretKey . ':');
        curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($ch, CURLOPT_HTTPGET, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
        ]);

        $resp = curl_exec($ch);
        $err = curl_error($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($err) {
            Log::error('Xendit HTTP request failed', ['error' => $err]);
            throw new \RuntimeException('Xendit request failed: ' . $err);
        }

        $decoded = json_decode($resp, true);
        Log::info('Xendit response (fallback)', ['status' => $code, 'body' => $decoded]);

        if ($code < 200 || $code >= 300) {
            $msg = is_array($decoded) && isset($decoded['message']) ? $decoded['message'] : $resp;
            throw new \RuntimeException('Xendit returned error: ' . $msg);
        }

        return $decoded ?? [];
    }
}
