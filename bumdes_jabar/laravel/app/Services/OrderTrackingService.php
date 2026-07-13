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
        $route = $this->fetchRoute($origin, $destination);

        if ($route !== null) {
            // Kurir "berjalan" mengikuti bentuk jalan sesungguhnya.
            $current = $this->interpolateAlongRoute($route['geometry'], $progress);
            $routeGeometry = $route['geometry'];
        } else {
            // OSRM tidak tersedia -> fallback ke garis lurus seperti semula.
            $current = $this->interpolate($origin, $destination, $progress);
            $routeGeometry = [$origin, $destination];
        }

        return [
            'order_id' => $order->id,
            'status' => $order->status,
            'origin' => $origin,
            'destination' => $destination,
            'current' => $current,
            // Daftar titik lat/lng yang membentuk rute (mengikuti jalan
            // sesungguhnya kalau OSRM tersedia, atau cuma 2 titik/garis
            // lurus sebagai fallback). Dipakai frontend untuk menggambar
            // polyline yang mengikuti jalan, bukan lagi garis lurus.
            'route' => $routeGeometry,
            'progress' => $progress,
            'estimated_delivery_minutes' => $order->estimated_delivery_minutes,
            'shipped_at' => optional($order->delivered_at)->toIso8601String(),
            'is_completed' => $progress >= 1,
        ];
    }

    // Endpoint OSRM publik (gratis, tanpa API key) untuk menghitung rute
    // jalan sesungguhnya (bukan garis lurus) antara dua titik. Ini server
    // demo publik milik proyek OSRM -- cocok untuk skala kecil/menengah,
    // tapi TIDAK ada jaminan uptime/SLA. Kalau nanti trafiknya besar,
    // sebaiknya self-host OSRM sendiri (masih gratis, open source).
    private const OSRM_URL = 'https://router.project-osrm.org/route/v1/driving';

    /**
     * Ambil rute jalan sesungguhnya dari OSRM antara dua titik: jarak (km),
     * durasi (menit versi mobil), dan geometry (daftar titik lat/lng yang
     * mengikuti jalan raya). Hasil di-cache per pasangan koordinat supaya
     * tidak membebani server OSRM publik dan supaya bentuk rute yang
     * ditampilkan konsisten setiap kali di-polling.
     *
     * Return null kalau OSRM gagal/timeout -- pemanggil WAJIB fallback ke
     * garis lurus (haversine), jangan biarkan fitur utama gagal gara-gara
     * servis eksternal opsional ini bermasalah.
     */
    private function fetchRoute(array $origin, array $destination): ?array
    {
        $cacheKey = 'route:'
            . round($origin['lat'], 5) . '_' . round($origin['lng'], 5) . ':'
            . round($destination['lat'], 5) . '_' . round($destination['lng'], 5);

        return Cache::remember($cacheKey, now()->addDays(14), function () use ($origin, $destination) {
            try {
                $url = self::OSRM_URL . "/{$origin['lng']},{$origin['lat']};{$destination['lng']},{$destination['lat']}";

                $response = Http::timeout(8)->get($url, [
                    'overview' => 'full',
                    'geometries' => 'geojson',
                ]);

                if (!$response->successful()) {
                    return null;
                }

                $data = $response->json();

                if (($data['code'] ?? null) !== 'Ok' || empty($data['routes'][0])) {
                    return null;
                }

                $route = $data['routes'][0];
                $coordinates = $route['geometry']['coordinates'] ?? [];

                // GeoJSON pakai urutan [lng, lat]; dibalik ke [lat, lng]
                // supaya konsisten dengan format titik lain di service ini.
                $geometry = array_map(
                    fn (array $point) => ['lat' => $point[1], 'lng' => $point[0]],
                    $coordinates,
                );

                if (count($geometry) < 2) {
                    return null;
                }

                return [
                    'distance_km' => $route['distance'] / 1000,
                    'duration_minutes' => $route['duration'] / 60,
                    'geometry' => $geometry,
                ];
            } catch (\Throwable $e) {
                Log::warning('OSRM routing gagal, fallback ke garis lurus', [
                    'origin' => $origin,
                    'destination' => $destination,
                    'error' => $e->getMessage(),
                ]);
                return null;
            }
        });
    }

    /**
     * Cari titik pada rute (daftar koordinat hasil OSRM) yang berada pada
     * proporsi `progress` (0..1) dari total panjang rute. Beda dengan
     * interpolate() biasa (garis lurus antara 2 titik), ini berjalan
     * MENGIKUTI bentuk jalan sesungguhnya, titik demi titik.
     */
    private function interpolateAlongRoute(array $geometry, float $progress): array
    {
        $count = count($geometry);
        if ($count === 0) {
            return ['lat' => 0.0, 'lng' => 0.0];
        }
        if ($count === 1) {
            return $geometry[0];
        }

        $progress = max(0.0, min(1.0, $progress));

        $segmentLengths = [];
        $totalLength = 0.0;
        for ($i = 0; $i < $count - 1; $i++) {
            $length = $this->haversineDistanceKm(
                $geometry[$i]['lat'],
                $geometry[$i]['lng'],
                $geometry[$i + 1]['lat'],
                $geometry[$i + 1]['lng'],
            );
            $segmentLengths[] = $length;
            $totalLength += $length;
        }

        if ($totalLength <= 0) {
            return $geometry[$count - 1];
        }

        $targetDistance = $totalLength * $progress;
        $walked = 0.0;

        for ($i = 0; $i < count($segmentLengths); $i++) {
            $segmentLength = $segmentLengths[$i];
            $isLastSegment = $i === count($segmentLengths) - 1;

            if ($walked + $segmentLength >= $targetDistance || $isLastSegment) {
                $segmentProgress = $segmentLength > 0
                    ? ($targetDistance - $walked) / $segmentLength
                    : 0.0;
                $segmentProgress = max(0.0, min(1.0, $segmentProgress));

                return $this->interpolate($geometry[$i], $geometry[$i + 1], $segmentProgress);
            }

            $walked += $segmentLength;
        }

        return $geometry[$count - 1];
    }

    // Kecepatan rata-rata kurir motor, termasuk berhenti/macet/jalan desa
    // campuran kota. Angka konservatif supaya estimasi tidak terlalu
    // optimis dibanding kondisi nyata di lapangan.
    private const AVERAGE_COURIER_SPEED_KMH = 30.0;

    // Waktu tambahan di luar perjalanan murni: ambil paket dari toko,
    // parkir, cari alamat, dll.
    private const PICKUP_BUFFER_MINUTES = 10;

    // Batas bawah/atas supaya estimasi tetap masuk akal walau jarak
    // hasil geocode sangat kecil (dekat sekali) atau sangat besar
    // (alamat ambigu / fallback jauh dari origin).
    private const MIN_ESTIMATED_MINUTES = 10;
    private const MAX_ESTIMATED_MINUTES = 240;

    /**
     * Hitung estimasi durasi pengiriman (menit) berdasarkan jarak lurus
     * (haversine) antara toko (origin) dan alamat pembeli (destination).
     * Dipanggil saat pesanan mulai dikirim, supaya progress "100%" nanti
     * benar-benar merepresentasikan "sudah sampai", bukan angka tetap
     * yang sama untuk semua pesanan.
     */
    public function calculateEstimatedMinutes(Order $order): int
    {
        $order = $this->ensureCoordinates($order);

        $origin = ['lat' => (float) $order->origin_lat, 'lng' => (float) $order->origin_lng];
        $destination = ['lat' => (float) $order->dest_lat, 'lng' => (float) $order->dest_lng];

        $route = $this->fetchRoute($origin, $destination);

        if ($route !== null) {
            // Durasi OSRM diasumsikan mobil; kurir motor umumnya sedikit
            // lebih gesit di jalan padat, tapi kita pakai apa adanya
            // (lebih konservatif/aman) lalu tambah buffer ambil paket.
            $totalMinutes = $route['duration_minutes'] + self::PICKUP_BUFFER_MINUTES;
        } else {
            // OSRM tidak tersedia -> fallback ke estimasi garis lurus.
            $distanceKm = $this->haversineDistanceKm(
                $origin['lat'],
                $origin['lng'],
                $destination['lat'],
                $destination['lng'],
            );
            $travelMinutes = ($distanceKm / self::AVERAGE_COURIER_SPEED_KMH) * 60;
            $totalMinutes = $travelMinutes + self::PICKUP_BUFFER_MINUTES;
        }

        return (int) round(max(
            self::MIN_ESTIMATED_MINUTES,
            min(self::MAX_ESTIMATED_MINUTES, $totalMinutes),
        ));
    }

    /**
     * Jarak garis lurus antara dua titik koordinat (km), pakai formula
     * haversine. Ini jarak "burung terbang", bukan jarak jalan raya
     * sesungguhnya -- cukup untuk estimasi kasar tanpa perlu API
     * routing berbayar.
     */
    private function haversineDistanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371.0;

        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);

        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lngDelta / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadiusKm * $c;
    }

    /**
     * Cek cepat apakah kurir sudah benar-benar sampai (progress >= 100%),
     * tanpa perlu geocoding/koordinat sama sekali -- cukup pakai status &
     * waktu order (lihat calculateProgress()). Dipakai sebagai gerbang
     * validasi di backend sebelum mengizinkan order ditandai "Selesai"
     * (baik oleh pembeli lewat confirmReceipt, maupun oleh penjual lewat
     * updateStatus), supaya aturan "belum 100% tidak bisa ditandai
     * selesai" tidak bisa dilewati lewat panggilan API langsung
     * (mis. dari Postman / devtools), bukan cuma dikunci di UI.
     */
    public function isDeliveryComplete(Order $order): bool
    {
        return $this->calculateProgress($order) >= 1.0;
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