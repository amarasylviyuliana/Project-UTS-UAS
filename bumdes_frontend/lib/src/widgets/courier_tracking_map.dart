import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_tracking_model.dart';
import '../services/order_tracking_service.dart';

/// Peta pelacakan kurir real-time (simulasi berbasis waktu, gratis,
/// pakai OpenStreetMap — tanpa API key/billing).
///
/// Widget ini polling endpoint tracking setiap [refreshInterval]. Supaya
/// marker kurir tidak "teleport" tiap kali data baru datang, posisi yang
/// ditampilkan di-interpolasi (animasi geser halus) dari posisi lama ke
/// posisi baru selama durasi [refreshInterval], memakai Ticker manual.
class CourierTrackingMap extends StatefulWidget {
  final String token;
  final int orderId;
  final Duration refreshInterval;

  /// Dipanggil setiap kali data tracking baru berhasil di-fetch dari
  /// server, supaya widget induk (misal OrderDetailScreen) bisa tahu
  /// progress pengiriman terkini (mis. untuk enable/disable tombol
  /// "Tandai Selesai" / "Konfirmasi Penerimaan").
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

class _CourierTrackingMapState extends State<CourierTrackingMap>
    with SingleTickerProviderStateMixin {
  final _service = OrderTrackingService();
  final _mapController = MapController();

  OrderTrackingModel? _tracking;
  String? _error;
  Timer? _timer;
  bool _mapReady = false;

  // BUG UTAMA (web tidak bisa diklik sama sekali / freeze total):
  //
  // Versi sebelumnya menaruh posisi marker yang sedang dianimasikan
  // (`_displayedCurrent`) di dalam state yang dipakai `setState()`, dan
  // setiap tick animasi (throttled ~8x/detik, TAPI TERUS-MENERUS selama
  // widget ini ada di layar) memanggil:
  //   1. setState() -> me-rebuild SELURUH widget CourierTrackingMap,
  //      termasuk TileLayer, PolylineLayer (rute penuh hasil OSRM, bisa
  //      ratusan titik), dan semua Marker -- bukan cuma marker kurirnya.
  //   2. _mapController.move() -> memindah kamera peta, yang memaksa
  //      flutter_map menghitung ulang tile mana saja yang perlu
  //      dimuat/digambar.
  //
  // Di Flutter Web, semuanya jalan di SATU thread yang sama dengan yang
  // memproses event klik/tap. Kalau thread itu terus-menerus sibuk
  // me-repaint tile peta + rute + kamera 8x/detik TANPA JEDA selama
  // halaman ini dibuka, event klik di MANA PUN di halaman (bukan cuma di
  // peta) jadi ikut tertahan di antrian dan terasa seperti "web-nya
  // freeze, tidak bisa diklik apa-apa".
  //
  // FIX:
  // - Posisi marker yang beranimasi sekarang disimpan di
  //   `ValueNotifier<LatLng>` terpisah (`_displayedCurrentNotifier`),
  //   BUKAN lewat setState() pada widget ini. Cuma bagian marker kurir
  //   (dibungkus ValueListenableBuilder) yang rebuild tiap tick --
  //   TileLayer, PolylineLayer, dan marker toko/tujuan TIDAK ikut
  //   di-rebuild ataupun di-repaint.
  // - Kamera peta TIDAK lagi dipindah otomatis di SETIAP tick animasi
  //   (yang sebelumnya bisa puluhan/ratusan kali selama widget ini
  //   dibuka). Kamera cukup disesuaikan sekali tiap kali data baru
  //   selesai di-poll (tiap [refreshInterval]), bukan tiap frame animasi.
  final ValueNotifier<LatLng?> _displayedCurrentNotifier = ValueNotifier(null);
  LatLng? _animStart;
  LatLng? _animEnd;
  DateTime? _animStartedAt;
  late final Ticker _ticker;

  // Throttle tambahan supaya animasi tetap halus dilihat mata (~8
  // update/detik) tanpa membebani main thread. Frame terakhir animasi
  // (t >= 1.0) tetap selalu diproses supaya posisi akhirnya presisi.
  static const Duration _minTickInterval = Duration(milliseconds: 120);
  DateTime? _lastAnimTickAt;

  LatLng? get _displayedCurrent => _displayedCurrentNotifier.value;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _tickAnimation())..start();
    _load();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _displayedCurrentNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    OrderTrackingModel data;
    try {
      data = await _service.fetchTrackingLocation(widget.token, widget.orderId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat lokasi kurir');
      return;
    }

    if (!mounted) return;

    final newCurrent = LatLng(data.current.lat, data.current.lng);
    final wasFirstLoad = _displayedCurrent == null;

    // `_tracking`/`_error` memang perlu setState karena mempengaruhi
    // tampilan (label progress, ikon selesai, dll). Ini cuma terjadi
    // sekali per [refreshInterval] (bukan per-frame), jadi jauh lebih
    // ringan dibanding rebuild per-tick animasi yang lama.
    setState(() {
      _tracking = data;
      _error = null;
    });

    if (wasFirstLoad) {
      // Load pertama kali: langsung tampilkan tanpa animasi.
      _animStart = null;
      _animEnd = null;
      _animStartedAt = null;
      _displayedCurrentNotifier.value = newCurrent;
    } else if (!data.isCompleted) {
      // Load berikutnya: animasikan dari posisi yang sedang ditampilkan
      // menuju posisi baru, selama kurang lebih durasi refreshInterval,
      // supaya gerakannya kelihatan halus/kontinu, bukan lompat instan.
      _animStart = _displayedCurrent;
      _animEnd = newCurrent;
      _animStartedAt = DateTime.now();
      _lastAnimTickAt = null;
    } else {
      _animStart = null;
      _animEnd = null;
      _animStartedAt = null;
      _displayedCurrentNotifier.value = newCurrent;
    }

    // Sesuaikan kamera SEKALI per poll (bukan per-frame animasi).
    if (_mapReady) {
      try {
        _mapController.move(newCurrent, _mapController.camera.zoom);
      } catch (_) {
        // Peta belum sepenuhnya siap; abaikan.
      }
    }

    // Beri tahu widget induk (mis. OrderDetailScreen) soal progress
    // terbaru, supaya ia bisa mengatur enable/disable tombol aksi.
    widget.onTrackingUpdate?.call(data);
  }

  void _tickAnimation() {
    if (_animStart == null || _animEnd == null || _animStartedAt == null) {
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_animStartedAt!);
    final t = (elapsed.inMilliseconds / widget.refreshInterval.inMilliseconds)
        .clamp(0.0, 1.0);
    final isFinalFrame = t >= 1.0;

    // Throttle: lewati frame ini kalau belum cukup waktu sejak update
    // terakhir, KECUALI ini frame terakhir animasi (biar posisi akhir
    // selalu presisi, tidak "kepotong" gara-gara throttle).
    if (!isFinalFrame &&
        _lastAnimTickAt != null &&
        now.difference(_lastAnimTickAt!) < _minTickInterval) {
      return;
    }
    _lastAnimTickAt = now;

    final lat = _animStart!.latitude +
        (_animEnd!.latitude - _animStart!.latitude) * t;
    final lng = _animStart!.longitude +
        (_animEnd!.longitude - _animStart!.longitude) * t;

    // Cuma update ValueNotifier -- TIDAK setState() pada widget ini, dan
    // TIDAK memindah kamera peta di sini. Ini yang membuat tile layer,
    // polyline, dan marker toko/tujuan tidak ikut rebuild/repaint tiap
    // tick, sehingga main thread tidak tersumbat dan klik/tap di
    // manapun di halaman tetap responsif.
    _displayedCurrentNotifier.value = LatLng(lat, lng);

    if (isFinalFrame) {
      _animStart = null;
      _animEnd = null;
      _animStartedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MessageBox(icon: Icons.wifi_off, message: _error!);
    }

    final tracking = _tracking;
    final initialCenter = _displayedCurrent;
    if (tracking == null || initialCenter == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final origin = LatLng(tracking.origin.lat, tracking.origin.lng);
    final destination = LatLng(tracking.destination.lat, tracking.destination.lng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13,
                onMapReady: () {
                  if (mounted) {
                    setState(() => _mapReady = true);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bumdesjabar.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      // Mengikuti bentuk jalan sesungguhnya (hasil OSRM) kalau
                      // tersedia; kalau backend fallback ke garis lurus,
                      // `tracking.route` otomatis cuma berisi [origin, destination].
                      points: tracking.route
                          .map((p) => LatLng(p.lat, p.lng))
                          .toList(),
                      strokeWidth: 3,
                      color: const Color(0xFF2A7F41).withValues(alpha: 0.5),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: origin,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.store, color: Color(0xFF2A7F41), size: 30),
                    ),
                    Marker(
                      point: destination,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.home, color: Colors.redAccent, size: 30),
                    ),
                  ],
                ),
                // Marker kurir dipisah ke MarkerLayer-nya sendiri dan
                // dibungkus ValueListenableBuilder, supaya cuma LAPISAN
                // INI yang rebuild tiap tick animasi (~8x/detik) -- bukan
                // TileLayer/PolylineLayer/marker toko & tujuan di atas.
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _displayedCurrentNotifier,
                  builder: (context, displayedCurrent, _) {
                    if (displayedCurrent == null) {
                      return const SizedBox.shrink();
                    }
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: displayedCurrent,
                          width: 40,
                          height: 40,
                          child: tracking.isCompleted
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                              : const _PulsingCourierIcon(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              tracking.isCompleted ? Icons.check_circle : Icons.delivery_dining,
              size: 18,
              color: const Color(0xFF2A7F41),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tracking.isCompleted
                    ? 'Paket sudah sampai tujuan'
                    : 'Kurir sedang dalam perjalanan (${_displayProgressPercent(tracking.progress)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Menghitung persentase yang ditampilkan ke user untuk progress kurir
/// yang BELUM selesai (`tracking.isCompleted == false`).
///
/// FIX BUG: sebelumnya teks ini pakai `toStringAsFixed(0)`, yang MEMBULATKAN
/// (bukan membulatkan ke bawah). Akibatnya kalau progress asli mis. 0.996
/// (99.6%), teks yang tampil jadi "100%" -- padahal `tracking.isCompleted`
/// masih false (progress belum benar-benar >= 1.0), sehingga marker di peta
/// masih di tengah rute dan tombol "Konfirmasi Penerimaan" masih terkunci.
/// Ini yang bikin tampilan kelihatan "nyangkut"/bug: teks bilang 100% tapi
/// semua hal lain berperilaku seperti belum sampai.
///
/// Fix: bulatkan ke BAWAH (floor), dan selama belum benar-benar
/// `isCompleted`, cap tampilan di 99% supaya angka "100%" hanya pernah
/// muncul lewat label "Paket sudah sampai tujuan", tidak pernah lewat sini.
int _displayProgressPercent(double progress) {
  final raw = (progress * 100).clamp(0, 100).floor();
  return raw >= 100 ? 99 : raw;
}

class _PulsingCourierIcon extends StatefulWidget {
  const _PulsingCourierIcon();

  @override
  State<_PulsingCourierIcon> createState() => _PulsingCourierIconState();
}

class _PulsingCourierIconState extends State<_PulsingCourierIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_controller.value * 0.25),
          child: child,
        );
      },
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFF2A7F41),
        child: Icon(Icons.delivery_dining, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageBox({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black45, size: 28),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}