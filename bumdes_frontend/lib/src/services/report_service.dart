import 'package:flutter/material.dart';
import '../models/financial_report_model.dart';
import '../models/order_model.dart';
import 'api_service.dart';

class ReportService {
  Future<Map<String, dynamic>> getPlatformReport(String token) async {
    final apiService = ApiService(token: token);
    final response = await apiService.get('/reports/platform');
    return Map<String, dynamic>.from(response);
  }

  Future<FinancialReportModel> getStoreReport({
    required String token,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '/reports/store';
      final params = <String, String>{};

      if (startDate != null && startDate.isNotEmpty) {
        params['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        params['end_date'] = endDate;
      }

      if (params.isNotEmpty) {
        url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }

      final apiService = ApiService(token: token);
      final response = await apiService.get(url);

      if (response['data'] != null) {
        return FinancialReportModel.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }
      throw Exception('No data in response');
    } catch (e) {
      debugPrint('getStoreReport error (akan pakai kalkulasi lokal): $e');
      rethrow;
    }
  }

  // ── DEFINISI TUNGGAL: order dihitung sebagai pendapatan HANYA kalau
  // statusnya 'Selesai'. Ini SAMA PERSIS dengan definisi yang dipakai di
  // getMonthlySalesData() dan getTopProducts() di bawah, dan sesuai dengan
  // logika backend (WalletService::creditFromCompletedOrder mengkredit
  // saldo toko saat order berubah jadi 'Selesai', bukan saat 'Dikonfirmasi'
  // atau baru berstatus pembayaran 'Lunas').
  //
  // SEBELUMNYA method calculateFromOrders() di bawah punya definisi
  // SENDIRI yang berbeda (status Selesai ATAU Dikonfirmasi ATAU
  // paymentStatus Lunas), sehingga saat endpoint /reports/store gagal dan
  // fallback ini aktif, kartu "Pendapatan" bisa menghitung order yang
  // belum genap 'Selesai' — padahal grafik Tren Penjualan & Produk
  // Terlaris di bawahnya cuma mengakui order 'Selesai'. Akibatnya angka
  // Pendapatan tidak pernah sinkron dengan Tren Penjualan / Produk
  // Terlaris. Sekarang SEMUA method di file ini memanggil helper yang
  // sama, supaya tidak mungkin lagi berbeda definisi.
  bool _isRevenueCounted(OrderModel order) => order.status == 'Selesai';

  /// Hitung laporan keuangan dari daftar pesanan (fallback / offline)
  FinancialReportModel calculateFromOrders(
    List<OrderModel> orders, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    startDate ??= DateTime.now().subtract(const Duration(days: 30));
    endDate ??= DateTime.now();

    // Filter berdasarkan rentang tanggal
    final filteredOrders = orders.where((order) {
      final orderDate = order.createdAt;
      return !orderDate.isBefore(startDate!) &&
          !orderDate.isAfter(endDate!.add(const Duration(days: 1)));
    }).toList();

    double totalRevenue = 0;
    int completedOrders = 0;

    for (final order in filteredOrders) {
      if (_isRevenueCounted(order)) {
        totalRevenue += order.total;
        completedOrders++;
      }
    }

    // Estimasi biaya operasional 25% dari pendapatan (HANYA dipakai kalau
    // /reports/store gagal total — bukan angka resmi dari backend).
    final totalExpense = totalRevenue * 0.25;
    final netProfit = totalRevenue - totalExpense;

    // Daftar transaksi: tetap tampilkan SEMUA order dalam periode (bukan
    // cuma yang Selesai) supaya tab "Transaksi" tetap informatif, tapi
    // beri kategori yang jelas mana yang sudah dihitung sebagai
    // pendapatan riil dan mana yang belum, supaya tidak disalahartikan
    // sebagai uang yang sudah masuk.
    final transactions = filteredOrders.map((order) {
      final counted = _isRevenueCounted(order);
      return TransactionModel(
        id: order.id,
        type: 'income',
        description: counted
            ? 'Penjualan - ${order.orderNumber}'
            : 'Penjualan (belum selesai) - ${order.orderNumber}',
        amount: order.total,
        date: order.createdAt,
        category: counted ? 'Penjualan' : 'Belum Selesai',
        orderId: order.id.toString(),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // terbaru di atas

    return FinancialReportModel(
      totalRevenue: totalRevenue,
      totalExpense: totalExpense,
      netProfit: netProfit,
      totalOrders: filteredOrders.length,
      completedOrders: completedOrders,
      transactions: transactions,
      period: 'Custom',
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Data penjualan per bulan — hanya order 'Selesai' (lihat _isRevenueCounted).
  List<MonthlySalesModel> getMonthlySalesData(List<OrderModel> orders) {
    final Map<String, MonthlySalesModel> monthlyData = {};

    final completedOrders = orders.where(_isRevenueCounted);

    for (final order in completedOrders) {
      final date = order.createdAt;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      if (monthlyData.containsKey(monthKey)) {
        final existing = monthlyData[monthKey]!;
        monthlyData[monthKey] = MonthlySalesModel(
          month: _formatMonthLabel(date),
          sales: existing.sales + order.total,
          orders: existing.orders + 1,
        );
      } else {
        monthlyData[monthKey] = MonthlySalesModel(
          month: _formatMonthLabel(date),
          sales: order.total,
          orders: 1,
        );
      }
    }

    return monthlyData.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  String _formatMonthLabel(DateTime date) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${months[date.month]} ${date.year}';
  }

  /// Produk terlaris — hanya order 'Selesai' (lihat _isRevenueCounted),
  /// konsisten dengan getMonthlySalesData dan calculateFromOrders.
  Map<String, dynamic> getTopProducts(List<OrderModel> orders) {
    final productSales = <String, Map<String, dynamic>>{};

    final completedOrders = orders.where(_isRevenueCounted);

    for (final order in completedOrders) {
      for (final item in order.items) {
        final productName = item.product.name;
        if (productSales.containsKey(productName)) {
          productSales[productName]!['quantity'] =
              (productSales[productName]!['quantity'] as int) + item.quantity;
          productSales[productName]!['total'] =
              (productSales[productName]!['total'] as double) + item.totalPrice;
        } else {
          productSales[productName] = {
            'quantity': item.quantity,
            'total': item.totalPrice,
            'price': item.unitPrice,
          };
        }
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) =>
          (b.value['total'] as num).compareTo(a.value['total'] as num));

    return {
      'products': Map.fromEntries(sortedProducts.take(10)),
      'total_products': sortedProducts.length,
    };
  }

  // ── FIX: Distribusi status pembayaran sekarang HANYA punya 3 bucket
  // tetap (Lunas / Belum Lunas / Ditolak), dan SETIAP order pasti masuk
  // ke salah satunya — tidak ada lagi bucket liar dengan key sembarang.
  //
  // SEBELUMNYA: kalau order.paymentStatus berisi nilai mentah yang tidak
  // persis cocok dengan 'Lunas'/'Belum Lunas'/'Pending'/'Ditolak' (bisa
  // terjadi karena OrderModel._parsePaymentStatus mengembalikan status
  // asli untuk kasus yang tidak dikenali), method ini membuat KATEGORI
  // BARU dengan nama status mentah itu. Kalau layar Analisis cuma
  // menampilkan baris "Lunas" dan "Belum Lunas" secara hardcoded, order
  // yang masuk kategori liar itu jadi tidak pernah muncul di layar —
  // padahal tetap terhitung di 'Total Pesanan'. Ini penyebab jumlah
  // "Lunas + Belum Lunas" di tab Analisis bisa lebih kecil dari
  // "Total Pesanan" di kartu lain.
  //
  // Sekarang: status apa pun yang bukan persis 'Lunas' atau 'Ditolak'
  // (termasuk null dan status mentah yang belum sempat dinormalisasi)
  // dikelompokkan sebagai 'Belum Lunas' — pilihan paling aman karena
  // artinya "belum terbukti sudah dibayar", bukan diam-diam dihilangkan
  // dari perhitungan.
  Map<String, int> getPaymentStatusDistribution(List<OrderModel> orders) {
    final distribution = <String, int>{
      'Lunas': 0,
      'Belum Lunas': 0,
      'Ditolak': 0,
    };

    for (final order in orders) {
      final status = order.paymentStatus;
      if (status == 'Lunas') {
        distribution['Lunas'] = distribution['Lunas']! + 1;
      } else if (status == 'Ditolak') {
        distribution['Ditolak'] = distribution['Ditolak']! + 1;
      } else {
        distribution['Belum Lunas'] = distribution['Belum Lunas']! + 1;
      }
    }

    // Hapus status dengan nilai 0 supaya UI lebih bersih.
    distribution.removeWhere((key, value) => value == 0);

    return distribution;
  }
}