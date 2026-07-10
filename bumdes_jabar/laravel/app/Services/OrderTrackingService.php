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
 *    Hasil geocoding DIVALIDASI harus berada di dalam bounding box
 *    Jawa Barat; kalau di luar itu (alamat ambigu / salah match),
 *    dibuang dan diganti titik fallback di sekitar salah satu kota
 *    besar Jawa Barat, supaya kurir tidak pernah muncul di luar
 *    provinsi.
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

    // Bounding box kasar Provinsi Jawa Barat. Sengaja dilebihkan sedikit
    // dari batas administratif asli supaya kota-kota di pinggiran (mis.
    // Banjar, Pangandaran) tetap masuk, tapi cukup ketat untuk menolak
    // hasil geocode yang melenceng ke Jakarta/Jawa Tengah/provinsi lain.
    private const JABAR_LAT_MIN = -7.85;
    private const JABAR_LAT_MAX = -5.85;
    private const JABAR_LNG_MIN = 106.35;
    private const JABAR_LNG_MAX = 108.85;

    // Titik tengah kota-kota besar Jawa Barat, dipakai sebagai fallback
    // kalau geocoding alamat gagal atau hasilnya keluar dari Jawa Barat.
    // Dipilih acak supaya demo tidak selalu terpusat di Bandung saja.
    private const JABAR_CITY_ANCHORS = [
        ['lat' => -6.9175, 'lng' => 107.6191], // Bandung
        ['lat' => -6.5971, 'lng' => 106.8060], // Bogor
        ['lat' => -6.4025, 'lng' => 106.7942], // Depok
        ['lat' => -6.2383, 'lng' => 106.9756], // Bekasi
        ['lat' => -6.8841, 'lng' => 107.5413], // Cimahi
        ['lat' => -7.3274, 'lng' => 108.2207], // Tasikmalaya
        ['lat' => -7.2151, 'lng' => 107.9001], // Garut
        ['lat' => -6.7320, 'lng' => 108.5523], // Cirebon
        ['lat' => -6.9277, 'lng' => 106.9300], // Sukabumi
        ['lat' => -6.3227, 'lng' => 107.3376], // Karawang
        ['lat' => -6.5569, 'lng' => 107.4432], // Purwakarta
        ['lat' => -6.5716, 'lng' => 107.7605], // Subang
        ['lat' => -6.3373, 'lng' => 108.3251], // Indramayu
        ['lat' => -6.8361, 'lng' => 108.2280], // Majalengka
        ['lat' => -6.9755, 'lng' => 108.4839], // Kuningan
        ['lat' => -7.3260, 'lng' => 108.3530], // Ciamis
        ['lat' => -7.6830, 'lng' => 108.6540], // Pangandaran
        ['lat' => -7.3714, 'lng' => 108.5340], // Banjar
    ];

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

            $origin = $this->geocodeWithinJabar($originAddress) ?? $this->randomJabarAnchor();

            $order->origin_lat = $origin['lat'];
            $order->origin_lng = $origin['lng'];
        }

        if (!$order->dest_lat || !$order->dest_lng) {
            $destAddress = trim($order->delivery_address . ', Jawa Barat, Indonesia');
            $dest = $this->geocodeWithinJabar($destAddress);

            if ($dest === null) {
                // Alamat tidak ketemu / hasilnya di luar Jawa Barat ->
                // taruh titik tujuan di sekitar origin dengan offset acak
                // kecil supaya peta tetap tampil masuk akal dan tetap di
                // Jawa Barat (origin sendiri sudah tervalidasi di atas).
                $origin = ['lat' => (float) $order->origin_lat, 'lng' => (float) $order->origin_lng];
                $dest = $this->clampToJabar([
                    'lat' => $origin['lat'] + (mt_rand(-800, 800) / 10000),
                    'lng' => $origin['lng'] + (mt_rand(-800, 800) / 10000),
                ]);
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
     * Dihitung ulang dari nol setiap request berdasarkan waktu absolut
     * (bukan increment per-polling), sehingga pergerakannya kontinu dan
     * konsisten secara matematis -- tidak pernah "meloncat" di sisi server.
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

    /**
     * Geocode alamat lewat Nominatim, lalu validasi hasilnya harus berada
     * di dalam bounding box Jawa Barat. Kalau geocoding gagal atau hasilnya
     * di luar Jawa Barat, kembalikan null (pemanggil akan pakai fallback).
     */
    private function geocodeWithinJabar(string $address): ?array
    {
        $result = $this->geocode($address);

        if ($result === null) {
            return null;
        }

        if (!$this->isWithinJabar($result)) {
            Log::info('Hasil geocode di luar Jawa Barat, memakai fallback', [
                'address' => $address,
                'result' => $result,
            ]);
            return null;
        }

        return $result;
    }

    private function isWithinJabar(array $point): bool
    {
        return $point['lat'] >= self::JABAR_LAT_MIN
            && $point['lat'] <= self::JABAR_LAT_MAX
            && $point['lng'] >= self::JABAR_LNG_MIN
            && $point['lng'] <= self::JABAR_LNG_MAX;
    }

    private function clampToJabar(array $point): array
    {
        return [
            'lat' => max(self::JABAR_LAT_MIN, min(self::JABAR_LAT_MAX, $point['lat'])),
            'lng' => max(self::JABAR_LNG_MIN, min(self::JABAR_LNG_MAX, $point['lng'])),
        ];
    }

    /**
     * Titik fallback: kota besar Jawa Barat dipilih acak, plus sedikit
     * offset acak (~0-3km) supaya tidak selalu persis di tengah kota.
     */
    private function randomJabarAnchor(): array
    {
        $anchor = self::JABAR_CITY_ANCHORS[array_rand(self::JABAR_CITY_ANCHORS)];

        return $this->clampToJabar([
            'lat' => $anchor['lat'] + (mt_rand(-300, 300) / 10000),
            'lng' => $anchor['lng'] + (mt_rand(-300, 300) / 10000),
        ]);
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
}