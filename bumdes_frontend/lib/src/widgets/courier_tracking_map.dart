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

  const CourierTrackingMap({
    super.key,
    required this.token,
    required this.orderId,
    this.refreshInterval = const Duration(seconds: 8),
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

  // Titik yang benar-benar ditampilkan di peta. Beda dengan
  // `_tracking.current` (posisi mentah dari server), titik ini bergerak
  // halus dari posisi lama ke posisi baru tiap kali data di-poll, alih-alih
  // langsung loncat (teleport) ke posisi baru.
  LatLng? _displayedCurrent;
  LatLng? _animStart;
  LatLng? _animEnd;
  DateTime? _animStartedAt;
  late final Ticker _ticker;

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

    setState(() {
      _tracking = data;
      _error = null;

      if (_displayedCurrent == null) {
        // Load pertama kali: langsung tampilkan tanpa animasi.
        _displayedCurrent = newCurrent;
        _animStart = null;
        _animEnd = null;
        _animStartedAt = null;
      } else if (!data.isCompleted) {
        // Load berikutnya: animasikan dari posisi yang sedang ditampilkan
        // menuju posisi baru, selama kurang lebih durasi refreshInterval,
        // supaya gerakannya kelihatan halus/kontinu, bukan lompat instan.
        _animStart = _displayedCurrent;
        _animEnd = newCurrent;
        _animStartedAt = DateTime.now();
      } else {
        _displayedCurrent = newCurrent;
        _animStart = null;
        _animEnd = null;
        _animStartedAt = null;
      }
    });
  }

  void _tickAnimation() {
    if (_animStart == null || _animEnd == null || _animStartedAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(_animStartedAt!);
    final t = (elapsed.inMilliseconds / widget.refreshInterval.inMilliseconds)
        .clamp(0.0, 1.0);

    final lat = _animStart!.latitude +
        (_animEnd!.latitude - _animStart!.latitude) * t;
    final lng = _animStart!.longitude +
        (_animEnd!.longitude - _animStart!.longitude) * t;
    final interpolated = LatLng(lat, lng);

    if (mounted) {
      setState(() => _displayedCurrent = interpolated);
    }

    if (_mapReady) {
      try {
        _mapController.move(interpolated, _mapController.camera.zoom);
      } catch (_) {
        // Peta belum sepenuhnya siap; abaikan, akan menyusul tick berikutnya.
      }
    }

    if (t >= 1.0) {
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
    final displayedCurrent = _displayedCurrent;
    if (tracking == null || displayedCurrent == null) {
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
                initialCenter: displayedCurrent,
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
                      points: [origin, destination],
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
                    Marker(
                      point: displayedCurrent,
                      width: 40,
                      height: 40,
                      child: tracking.isCompleted
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                          : const _PulsingCourierIcon(),
                    ),
                  ],
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
                    : 'Kurir sedang dalam perjalanan (${(tracking.progress * 100).clamp(0, 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
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