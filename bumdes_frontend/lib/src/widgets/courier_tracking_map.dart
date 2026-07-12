import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_tracking_model.dart';
import '../services/order_tracking_service.dart';

/// Status pelacakan kurir — versi DENGAN peta interaktif (flutter_map).
///
/// Dibangun di atas pelajaran dari versi map lama yang sempat bikin web
/// freeze. Aturan yang dipegang di sini supaya tidak terulang:
///
/// 1. TIDAK ADA animasi kamera (tidak pakai Ticker/AnimatedMapController).
///    Perpindahan peta pakai `mapController.move()` biasa — instan,
///    murah, tidak ada animation loop yang bisa nyangkut di background.
/// 2. Auto-center OTOMATIS MATI begitu user menggeser peta sendiri
///    (dideteksi lewat `MapEventMove` yang `source` bukan
///    `MapEventSource.mapController`), supaya peta tidak "lompat-lompat"
///    tiap kali polling (~8 detik) dan mengganggu interaksi user.
/// 3. Update posisi marker lewat `ValueNotifier` + `ValueListenableBuilder`
///    yang di-scope KECIL (cuma marker layer), BUKAN `setState` di root
///    widget yang me-rebuild seluruh peta/tile.
/// 4. `dispose()` membatalkan timer polling. `FlutterMap`/`MapController`
///    tidak butuh dispose eksplisit (tidak pegang resource web/JS di
///    luar Flutter seperti kasus Midtrans snap.js), jadi aman ditinggal
///    berpindah halaman selama widget-nya sendiri ter-unmount normal.
/// 5. Widget ini di-scope kecil (section "Lokasi Kurir" saja). `setState`
///    di sini TIDAK memicu rebuild `OrderDetailScreen` — selaras dengan
///    `_handleTrackingUpdate` di parent yang cuma rebuild saat status
///    "sudah sampai" berubah.
///
/// CATATAN dependency: tambahkan ke pubspec.yaml bila belum ada:
///   flutter_map: ^7.0.2
///   latlong2: ^0.9.1
///
/// Peta menampilkan 3 hal dari `OrderTrackingModel`: posisi kurir saat
/// ini (`current`), titik asal (`origin`), titik tujuan (`destination`),
/// dan garis rute (`route` — mengikuti jalan sesungguhnya kalau backend
/// berhasil hitung lewat OSRM, atau garis lurus origin→destination bila
/// tidak).
class CourierTrackingMap extends StatefulWidget {
  final String token;
  final int orderId;
  final Duration refreshInterval;
  final ValueChanged<OrderTrackingModel>? onTrackingUpdate;

  const CourierTrackingMap({
    super.key,
    required this.token,
    required this.orderId,
    this.refreshInterval = const Duration(seconds: 8),
    this.onTrackingUpdate,
  });

  @override
  State<CourierTrackingMap> createState() => _CourierTrackingMapState();
}

class _CourierTrackingMapState extends State<CourierTrackingMap> {
  final _service = OrderTrackingService();
  final _mapController = MapController();

  // Posisi & data kurir disimpan di ValueNotifier supaya listener-nya
  // bisa di-scope ke widget kecil (marker saja), tanpa memicu setState
  // pada seluruh subtree peta.
  final ValueNotifier<OrderTrackingModel?> _trackingNotifier =
      ValueNotifier(null);

  Timer? _timer;
  String? _error;
  bool _mapReady = false;
  bool _userMovedMap = false; // auto-center mati begitu user geser peta

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _trackingNotifier.dispose();
    super.dispose();
  }

  LatLng _pointToLatLng(LatLngPoint p) => LatLng(p.lat, p.lng);

  LatLng _currentLatLng(OrderTrackingModel t) => _pointToLatLng(t.current);

  List<LatLng> _routeLatLngs(OrderTrackingModel t) {
    if (t.route.isEmpty) {
      // Fallback: garis lurus origin -> destination, sama seperti
      // fallback yang sudah dilakukan di OrderTrackingModel.fromJson.
      return [_pointToLatLng(t.origin), _pointToLatLng(t.destination)];
    }
    return t.route.map(_pointToLatLng).toList();
  }

  Future<void> _load() async {
    OrderTrackingModel data;
    try {
      data = await _service.fetchTrackingLocation(widget.token, widget.orderId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat status pengiriman');
      return;
    }

    if (!mounted) return;

    // Hanya rebuild bagian teks status/error jika benar-benar berubah
    // (error hilang atau baru muncul). Update posisi kurir TIDAK lewat
    // setState di sini — cukup lewat notifier di bawah, supaya peta
    // tidak ikut rebuild penuh tiap 8 detik.
    if (_error != null) {
      setState(() => _error = null);
    }
    _trackingNotifier.value = data;

    // Auto-center peta ke posisi kurir TANPA animasi, dan HANYA jika
    // user belum pernah menggeser peta secara manual.
    final latLng = _currentLatLng(data);
    if (_mapReady && !_userMovedMap) {
      _mapController.move(latLng, _mapController.camera.zoom);
    }

    // Tetap teruskan ke parent (OrderDetailScreen) seperti sebelumnya,
    // untuk logic enable/disable tombol aksi.
    widget.onTrackingUpdate?.call(data);
  }

  void _onMapEvent(MapEvent event) {
    // Deteksi gesture manual dari user (drag/pinch), BUKAN perpindahan
    // yang kita picu sendiri lewat mapController.move() di atas.
    if (event.source == MapEventSource.onDrag ||
        event.source == MapEventSource.multiFingerEnd ||
        event.source == MapEventSource.flingAnimationController) {
      if (!_userMovedMap) {
        setState(() => _userMovedMap = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status + progress bar ditaruh SEBAGAI ELEMEN TERPISAH di atas
        // peta (bukan Positioned overlay di dalam peta) — supaya tidak
        // tumpang tindih dengan tile/label jalan di peta.
        ValueListenableBuilder<OrderTrackingModel?>(
          valueListenable: _trackingNotifier,
          builder: (context, tracking, _) {
            if (_error != null && tracking == null) {
              return const _StatusCard(
                icon: Icons.wifi_off,
                text: 'Gagal memuat status pengiriman',
                progress: null,
              );
            }
            if (tracking == null) {
              return const _StatusCard(
                icon: Icons.delivery_dining,
                text: 'Memuat status pengiriman...',
                progress: null,
              );
            }
            final percent = _displayProgressPercent(tracking.progress);
            return _StatusCard(
              icon: tracking.isCompleted
                  ? Icons.check_circle
                  : Icons.delivery_dining,
              text: tracking.isCompleted
                  ? 'Paket sudah sampai tujuan'
                  : 'Kurir sedang dalam perjalanan ($percent%)',
              progress:
                  tracking.isCompleted ? 1.0 : tracking.progress.clamp(0.0, 1.0),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildMap(),
      ],
    );
  }

  Widget _buildMap() {
    if (_error != null && _trackingNotifier.value == null) {
      return const _MapShell(
        child: _StatusOverlay(
          icon: Icons.wifi_off,
          text: 'Gagal memuat peta',
        ),
      );
    }

    // Tunggu sampai data lokasi kurir yang PERTAMA benar-benar masuk
    // sebelum me-render peta. Tidak ada fallback center hardcoded (mis.
    // Jawa Barat) — kalau dipaksa render duluan dengan center sembarang,
    // untuk order di luar area itu peta akan sempat nongol salah lokasi
    // dulu sebelum "melompat" ke posisi asli begitu data masuk.
    final initialTracking = _trackingNotifier.value;
    final initialLatLng =
        initialTracking != null ? _currentLatLng(initialTracking) : null;

    if (initialLatLng == null) {
      return const _MapShell(
        child: _StatusOverlay(
          icon: Icons.delivery_dining,
          text: 'Memuat lokasi kurir...',
        ),
      );
    }

    return _MapShell(
      child: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialLatLng,
                initialZoom: 15,
                minZoom: 5,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
                onMapReady: () {
                  _mapReady = true;
                  final t = _trackingNotifier.value;
                  if (t != null) {
                    _mapController.move(_currentLatLng(t), 15);
                  }
                },
                onMapEvent: _onMapEvent,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bumdesjabar.app',
                  // Batasi jumlah tile yang di-fetch/di-cache demi ringan
                  // di web — cukup, tidak perlu prefetch berlebihan.
                  maxNativeZoom: 18,
                ),
                // Garis rute origin -> destination (pakai `route` dari
                // backend kalau ada, mengikuti bentuk jalan sesungguhnya;
                // fallback garis lurus kalau backend belum kirim route).
                ValueListenableBuilder<OrderTrackingModel?>(
                  valueListenable: _trackingNotifier,
                  builder: (context, tracking, _) {
                    if (tracking == null) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routeLatLngs(tracking),
                          strokeWidth: 4,
                          color: const Color(0xFF2A7F41).withValues(alpha: 0.6),
                        ),
                      ],
                    );
                  },
                ),
                // Marker asal & tujuan (kalau posisi kurir sudah persis
                // di titik tujuan / sudah selesai, marker "kurir" akan
                // menutupi marker tujuan — itu wajar/disengaja, bukan
                // bug, karena artinya kurir memang sudah tiba tepat di
                // lokasi tersebut).
                ValueListenableBuilder<OrderTrackingModel?>(
                  valueListenable: _trackingNotifier,
                  builder: (context, tracking, _) {
                    if (tracking == null) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: _pointToLatLng(tracking.origin),
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.store,
                            color: Colors.black54,
                            size: 22,
                          ),
                        ),
                        // Marker tujuan disembunyikan begitu status
                        // selesai, supaya tidak numpuk persis di bawah
                        // marker posisi kurir saat ini.
                        if (!tracking.isCompleted)
                          Marker(
                            point: _pointToLatLng(tracking.destination),
                            width: 30,
                            height: 30,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.flag,
                              color: Colors.redAccent,
                              size: 26,
                            ),
                          ),
                        Marker(
                          point: _currentLatLng(tracking),
                          width: 42,
                          height: 42,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            tracking.isCompleted
                                ? Icons.location_on
                                : Icons.delivery_dining,
                            color: const Color(0xFF2A7F41),
                            size: 34,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Tombol kecil untuk kembali auto-center kalau user tadi
          // sudah menggeser peta secara manual.
          if (_userMovedMap)
            Positioned(
              right: 10,
              bottom: 10,
              child: FloatingActionButton.small(
                heroTag: 'recenter_courier_map',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2A7F41),
                onPressed: () {
                  final t = _trackingNotifier.value;
                  if (t != null) {
                    _mapController.move(
                      _currentLatLng(t),
                      _mapController.camera.zoom,
                    );
                  }
                  setState(() => _userMovedMap = false);
                },
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card status + progress bar yang berdiri sendiri DI LUAR peta —
/// sengaja dipisah dari peta (bukan Positioned overlay di atasnya)
/// supaya tidak tumpang tindih dengan tile/label jalan.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final double? progress;

  const _StatusCard({
    required this.icon,
    required this.text,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2A7F41), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2A7F41)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dibulatkan ke BAWAH dan di-cap 99% selama belum benar-benar
/// `isCompleted`, supaya teks tidak pernah salah bilang "100%" sebelum
/// kurir benar-benar sampai.
int _displayProgressPercent(double progress) {
  final raw = (progress * 100).clamp(0, 100).floor();
  return raw >= 100 ? 99 : raw;
}

/// Bungkus peta dengan tinggi tetap (bukan double.infinity) supaya
/// layout web tidak melar tak terkendali dan tile yang di-render
/// terbatas jumlahnya.
class _MapShell extends StatelessWidget {
  final Widget child;
  const _MapShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: child,
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatusOverlay({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5FBF6),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black45, size: 28),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}