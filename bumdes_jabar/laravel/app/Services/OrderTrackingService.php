<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * OrderTrackingService
 *
 * Menyediakan data untuk fitur "Peta Pelacakan Kurir" tanpa perlu
 * app kurir terpisah maupun API berbayar (Google Maps/expedisi):
 *
 * 1. Geocoding alamat -> koordinat, pakai Nominatim (OpenStreetMap),
 *    gratis & tanpa API key. Hasilnya di-cache supaya tidak spam
 *    request (kebijakan fair-use Nominatim: max ~1 request/detik).
 * 2. Posisi kurir "saat ini" TIDAK disimpan & di-update manual.
 *    Sebaliknya, dihitung on-the-fly dengan interpolasi linear antara
 *    titik asal (toko) dan titik tujuan (alamat pembeli), berdasarkan
 *    proporsi waktu yang sudah berlalu sejak status berubah jadi
 *    "Dikirim" dibanding estimasi total durasi pengiriman. Hasilnya:
 *    marker di peta konsisten "bergerak" tiap kali di-refresh, terasa
 *    real-time, padahal 100% gratis & tanpa infrastruktur tambahan.
 */
class OrderTrackingService
{
    private const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';

    /**
     * Pastikan order punya koordinat asal & tujuan. Kalau belum ada,
     * geocode dari alamat toko (asal) dan alamat pengiriman (tujuan)
     * lalu simpan ke kolom order supaya tidak perlu geocode ulang.
     */
    public function ensureCoordinates(Order $order): Order
    {
        $order->loadMissing('store');

        if (!$order->origin_lat || !$order->origin_lng) {
            $store = $order->store;
            $originAddress = trim(implode(', ', array_filter([
                $store?->address,
                $store?->village,
                $store?->district,
                $store?->regency,
                'Jawa Barat, Indonesia',
            ])));

            $origin = $this->geocode($originAddress) ?? $this->fallbackBandungCoordinate();

            $order->origin_lat = $origin['lat'];
            $order->origin_lng = $origin['lng'];
        }

        if (!$order->dest_lat || !$order->dest_lng) {
            $destAddress = trim($order->delivery_address . ', Jawa Barat, Indonesia');
            $dest = $this->geocode($destAddress);

            if ($dest === null) {
                // Alamat tidak ketemu di OSM (input bebas dari user) ->
                // taruh titik tujuan di sekitar origin dengan offset acak
                // kecil supaya peta tetap tampil masuk akal, bukan error.
                $origin = ['lat' => (float) $order->origin_lat, 'lng' => (float) $order->origin_lng];
                $dest = [
                    'lat' => $origin['lat'] + (mt_rand(-800, 800) / 10000),
                    'lng' => $origin['lng'] + (mt_rand(-800, 800) / 10000),
                ];
            }

            $order->dest_lat = $dest['lat'];
            $order->dest_lng = $dest['lng'];
        }

        if ($order->isDirty(['origin_lat', 'origin_lng', 'dest_lat', 'dest_lng'])) {
            $order->save();
        }

        return $order;
    }

    /**
     * Hitung payload lengkap untuk endpoint tracking: titik asal, tujuan,
     * posisi kurir saat ini (hasil interpolasi), dan progres 0..1.
     */
    public function buildTrackingPayload(Order $order): array
    {
        $order = $this->ensureCoordinates($order);

        $origin = ['lat' => (float) $order->origin_lat, 'lng' => (float) $order->origin_lng];
        $destination = ['lat' => (float) $order->dest_lat, 'lng' => (float) $order->dest_lng];

        $progress = $this->calculateProgress($order);
        $current = $this->interpolate($origin, $destination, $progress);

        return [
            'order_id' => $order->id,
            'status' => $order->status,
            'origin' => $origin,
            'destination' => $destination,
            'current' => $current,
            'progress' => $progress,
            'estimated_delivery_minutes' => $order->estimated_delivery_minutes,
            'shipped_at' => optional($order->delivered_at)->toIso8601String(),
            'is_completed' => $progress >= 1,
        ];
    }

    /**
     * Progres perjalanan 0..1 berdasarkan waktu berlalu sejak dikirim.
     */
    private function calculateProgress(Order $order): float
    {
        if (in_array($order->status, ['Selesai'], true)) {
            return 1.0;
        }

        if (!in_array($order->status, ['Dikirim', 'Estimasi Sampai'], true) || !$order->delivered_at) {
            return 0.0;
        }

        $elapsedMinutes = now()->diffInSeconds($order->delivered_at) / 60;
        $totalMinutes = max(1, (int) $order->estimated_delivery_minutes);

        return max(0.0, min(1.0, $elapsedMinutes / $totalMinutes));
    }

    private function interpolate(array $origin, array $destination, float $progress): array
    {
        return [
            'lat' => $origin['lat'] + ($destination['lat'] - $origin['lat']) * $progress,
            'lng' => $origin['lng'] + ($destination['lng'] - $origin['lng']) * $progress,
        ];
    }

    private function geocode(string $address): ?array
    {
        if ($address === '') {
            return null;
        }

        $cacheKey = 'geocode:' . md5(strtolower($address));

        return Cache::remember($cacheKey, now()->addDays(30), function () use ($address) {
            try {
                $response = Http::withHeaders([
                    // Nominatim usage policy mewajibkan User-Agent yang jelas.
                    'User-Agent' => 'BUMDesJabarApp/1.0 (contact: admin@bumdesjabar.local)',
                ])->get(self::NOMINATIM_URL, [
                    'q' => $address,
                    'format' => 'json',
                    'limit' => 1,
                    'countrycodes' => 'id',
                ]);

                if (!$response->successful()) {
                    return null;
                }

                $results = $response->json();

                if (empty($results)) {
                    return null;
                }

                return [
                    'lat' => (float) $results[0]['lat'],
                    'lng' => (float) $results[0]['lon'],
                ];
            } catch (\Throwable $e) {
                Log::warning('Geocoding gagal', ['address' => $address, 'error' => $e->getMessage()]);
                return null;
            }
        });
    }

    /**
     * Fallback titik tengah Bandung, dipakai kalau alamat toko kosong/
     * tidak bisa di-geocode, supaya fitur tetap jalan untuk demo.
     */
    private function fallbackBandungCoordinate(): array
    {
        return ['lat' => -6.9175, 'lng' => 107.6191];
    }
}