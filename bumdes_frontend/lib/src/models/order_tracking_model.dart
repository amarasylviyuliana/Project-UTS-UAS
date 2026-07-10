class LatLngPoint {
  final double lat;
  final double lng;

  const LatLngPoint({required this.lat, required this.lng});

  factory LatLngPoint.fromJson(Map<String, dynamic> json) {
    return LatLngPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Data lokasi pelacakan kurir untuk sebuah pesanan.
/// Posisi [current] dihitung server-side berdasarkan waktu berjalan sejak
/// pesanan dikirim, jadi setiap kali data ini diambil ulang (polling),
/// titik kurir akan sedikit bergeser menuju [destination].
///
/// [route] adalah daftar titik yang membentuk jalur pengiriman -- kalau
/// backend berhasil menghitung rute jalan sesungguhnya (lewat OSRM), titik
/// ini mengikuti bentuk jalan raya; kalau tidak, backend mengirim fallback
/// berupa 2 titik saja (origin & destination / garis lurus).
class OrderTrackingModel {
  final int orderId;
  final String status;
  final LatLngPoint origin;
  final LatLngPoint destination;
  final LatLngPoint current;
  final List<LatLngPoint> route;
  final double progress;
  final int estimatedDeliveryMinutes;
  final DateTime? shippedAt;
  final bool isCompleted;

  const OrderTrackingModel({
    required this.orderId,
    required this.status,
    required this.origin,
    required this.destination,
    required this.current,
    required this.route,
    required this.progress,
    required this.estimatedDeliveryMinutes,
    required this.shippedAt,
    required this.isCompleted,
  });

  factory OrderTrackingModel.fromJson(Map<String, dynamic> json) {
    final origin = LatLngPoint.fromJson(
      Map<String, dynamic>.from(json['origin'] as Map? ?? {}),
    );
    final destination = LatLngPoint.fromJson(
      Map<String, dynamic>.from(json['destination'] as Map? ?? {}),
    );

    final rawRoute = json['route'];
    final route = (rawRoute is List && rawRoute.isNotEmpty)
        ? rawRoute
            .map((point) => LatLngPoint.fromJson(
                  Map<String, dynamic>.from(point as Map? ?? {}),
                ))
            .toList()
        // Fallback kalau backend belum kirim field `route` sama sekali
        // (mis. versi API lama): pakai garis lurus origin -> destination,
        // sama seperti perilaku sebelumnya.
        : [origin, destination];

    return OrderTrackingModel(
      orderId: json['order_id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      origin: origin,
      destination: destination,
      current: LatLngPoint.fromJson(
        Map<String, dynamic>.from(json['current'] as Map? ?? {}),
      ),
      route: route,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      estimatedDeliveryMinutes:
          json['estimated_delivery_minutes'] as int? ?? 180,
      shippedAt: json['shipped_at'] != null
          ? DateTime.tryParse(json['shipped_at'] as String)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}