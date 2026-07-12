import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_tracking_model.dart';
import '../services/order_tracking_service.dart';

/// Status pelacakan kurir — versi RINGAN, TANPA peta interaktif.
///
/// CATATAN: nama class ini sengaja tetap `CourierTrackingMap` (bukan
/// diganti nama) supaya file ini bisa langsung menimpa file lama tanpa
/// perlu mengubah import/pemanggilan di `order_detail_screen.dart`
/// maupun `order_tracking_screen.dart`.
///
/// Versi sebelumnya pakai `FlutterMap` (tile OpenStreetMap + rute +
/// animasi kamera pakai Ticker), yang ternyata berat di Flutter Web dan
/// sempat menyebabkan halaman Detail Pesanan tidak responsif terhadap
/// klik. Versi ini menggantinya dengan tampilan sederhana: ikon + teks
/// status + progress bar, TANPA render peta/tile sama sekali, TANPA
/// Ticker/animasi kamera — cuma polling data yang sama tiap
/// [refreshInterval] lalu ditampilkan sebagai teks & progress bar.
///
/// Fungsi [onTrackingUpdate] (dipakai OrderDetailScreen untuk
/// enable/disable tombol "Tandai Selesai" / "Konfirmasi Penerimaan"
/// begitu progress mencapai 100%) tetap sama persis seperti sebelumnya.
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
  Timer? _timer;
  OrderTrackingModel? _tracking;
  String? _error;

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
    OrderTrackingModel data;
    try {
      data = await _service.fetchTrackingLocation(widget.token, widget.orderId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat status pengiriman');
      return;
    }

    if (!mounted) return;
    setState(() {
      _tracking = data;
      _error = null;
    });

    // Beri tahu widget induk (mis. OrderDetailScreen) soal progress
    // terbaru, supaya ia bisa mengatur enable/disable tombol aksi.
    widget.onTrackingUpdate?.call(data);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _StatusCard(
        icon: Icons.wifi_off,
        iconColor: Colors.black45,
        title: _error!,
        progress: null,
      );
    }

    final tracking = _tracking;
    if (tracking == null) {
      return const _StatusCard(
        icon: Icons.delivery_dining,
        iconColor: Color(0xFF2A7F41),
        title: 'Memuat status pengiriman...',
        progress: null,
      );
    }

    final percent = _displayProgressPercent(tracking.progress);

    return _StatusCard(
      icon: tracking.isCompleted ? Icons.check_circle : Icons.delivery_dining,
      iconColor: const Color(0xFF2A7F41),
      title: tracking.isCompleted
          ? 'Paket sudah sampai tujuan'
          : 'Kurir sedang dalam perjalanan ($percent%)',
      progress: tracking.isCompleted ? 1.0 : tracking.progress.clamp(0.0, 1.0),
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

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double? progress;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
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