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
  bool _isRevenueCounted(OrderModel order) => order.status == 'Selesai';

  /// Hitung laporan keuangan dari daftar pesanan (fallback / offline)
  FinancialReportModel calculateFromOrders(
    List<OrderModel> orders, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    startDate ??= DateTime.now().subtract(const Duration(days: 30));
    endDate ??= DateTime.now();

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

    final totalExpense = totalRevenue * 0.25;
    final netProfit = totalRevenue - totalExpense;

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
      ..sort((a, b) => b.date.compareTo(a.date));

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

    distribution.removeWhere((key, value) => value == 0);

    return distribution;
  }
}