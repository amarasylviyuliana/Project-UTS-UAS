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
      // FIX: Hilangkan /api/ di depan — ApiService sudah tambah base URL sendiri
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
      // Jika API tidak ada endpoint ini, fallback ke kalkulasi lokal
      throw Exception('No data in response');
    } catch (e) {
      debugPrint('getStoreReport error (akan pakai kalkulasi lokal): $e');
      rethrow;
    }
  }

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
      // Hitung sebagai pendapatan jika status Selesai atau Dikonfirmasi atau sudah Lunas
      final isDone = order.status == 'Selesai' ||
          order.status == 'Dikonfirmasi' ||
          order.paymentStatus == 'Lunas';
      if (isDone) {
        totalRevenue += order.total;
        completedOrders++;
      }
    }

    // Estimasi biaya operasional 25% dari pendapatan
    final totalExpense = totalRevenue * 0.25;
    final netProfit = totalRevenue - totalExpense;

    // Buat daftar transaksi
    final transactions = filteredOrders.map((order) {
      return TransactionModel(
        id: order.id,
        type: 'income',
        description: 'Penjualan - ${order.orderNumber}',
        amount: order.total,
        date: order.createdAt,
        category: 'Penjualan',
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

  /// Data penjualan per bulan
  List<MonthlySalesModel> getMonthlySalesData(List<OrderModel> orders) {
    final Map<String, MonthlySalesModel> monthlyData = {};

    for (final order in orders) {
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

  /// Produk terlaris dari daftar pesanan
  Map<String, dynamic> getTopProducts(List<OrderModel> orders) {
    final productSales = <String, Map<String, dynamic>>{};

    for (final order in orders) {
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

  /// Distribusi status pembayaran
  Map<String, int> getPaymentStatusDistribution(List<OrderModel> orders) {
    final distribution = <String, int>{
      'Lunas': 0,
      'Belum Lunas': 0,
      'Pending': 0,
      'Ditolak': 0,
    };

    for (final order in orders) {
      final status = order.paymentStatus ?? 'Pending';
      if (distribution.containsKey(status)) {
        distribution[status] = distribution[status]! + 1;
      } else {
        distribution[status] = 1;
      }
    }

    // Hapus status dengan nilai 0 supaya UI lebih bersih
    distribution.removeWhere((key, value) => value == 0);

    return distribution;
  }
}