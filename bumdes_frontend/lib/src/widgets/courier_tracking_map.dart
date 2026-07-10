import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_tracking_model.dart';
import '../services/order_tracking_service.dart';

/// Peta pelacakan kurir real-time (simulasi berbasis waktu, gratis,
/// pakai OpenStreetMap — tanpa API key/billing).
///
/// Widget ini polling endpoint tracking setiap [refreshInterval] supaya
/// marker kurir terlihat bergerak dari toko menuju alamat pembeli.
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

class _CourierTrackingMapState extends State<CourierTrackingMap> {
  final _service = OrderTrackingService();
  final _mapController = MapController();

  OrderTrackingModel? _tracking;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _service.fetchTrackingLocation(
        widget.token,
        widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _tracking = data;
        _error = null;
      });

      if (!_tracking!.isCompleted) {
        _mapController.move(
          LatLng(_tracking!.current.lat, _tracking!.current.lng),
          _mapController.camera.zoom,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat lokasi kurir');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MessageBox(icon: Icons.wifi_off, message: _error!);
    }

    final tracking = _tracking;
    if (tracking == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final origin = LatLng(tracking.origin.lat, tracking.origin.lng);
    final destination = LatLng(tracking.destination.lat, tracking.destination.lng);
    final current = LatLng(tracking.current.lat, tracking.current.lng);

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
                initialCenter: current,
                initialZoom: 13,
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
                      color: const Color(0xFF2A7F41).withOpacity(0.5),
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
                      point: current,
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