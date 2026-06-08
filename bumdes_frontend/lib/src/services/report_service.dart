import 'package:flutter/material.dart';
import '../models/financial_report_model.dart';
import '../models/order_model.dart';
import 'api_service.dart';

class ReportService {
  Future<FinancialReportModel> getStoreReport({
    required String token,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '/api/reports/store';
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
        return FinancialReportModel.fromJson(response['data'] as Map<String, dynamic>);
      }
      throw Exception('No data in response');
    } catch (e) {
      debugPrint('Error fetching store report: $e');
      rethrow;
    }
  }

  /// Calculate financial data from orders
  /// This method is used as fallback when API doesn't provide full report
  FinancialReportModel calculateFromOrders(
    List<OrderModel> orders, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    startDate ??= DateTime.now().subtract(const Duration(days: 30));
    endDate ??= DateTime.now();

    // Filter orders by date range
    final filteredOrders = orders.where((order) {
      final orderDate = order.createdAt;
      return orderDate.isAfter(startDate!) &&
          orderDate.isBefore(endDate!.add(const Duration(days: 1)));
    }).toList();

    // Calculate metrics
    double totalRevenue = 0;
    int completedOrders = 0;

    for (final order in filteredOrders) {
      if (order.status == 'Selesai' || order.paymentStatus == 'Lunas') {
        totalRevenue += order.total;
        completedOrders++;
      }
    }

    // Estimate expenses (approximately 20-30% of revenue for typical margins)
    final totalExpense = totalRevenue * 0.25;
    final netProfit = totalRevenue - totalExpense;

    // Create transaction list from orders
    final transactions = <TransactionModel>[];
    for (final order in filteredOrders) {
      transactions.add(
        TransactionModel(
          id: order.id,
          type: 'income',
          description: 'Penjualan - ${order.orderNumber}',
          amount: order.total,
          date: order.createdAt,
          category: 'Penjualan',
          orderId: order.id.toString(),
        ),
      );
    }

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

  /// Get monthly sales data
  List<MonthlySalesModel> getMonthlySalesData(List<OrderModel> orders) {
    final Map<String, MonthlySalesModel> monthlyData = {};

    for (final order in orders) {
      final date = order.createdAt;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      if (monthlyData.containsKey(monthKey)) {
        final existing = monthlyData[monthKey]!;
        monthlyData[monthKey] = MonthlySalesModel(
          month: monthKey,
          sales: existing.sales + order.total,
          orders: existing.orders + 1,
        );
      } else {
        monthlyData[monthKey] = MonthlySalesModel(
          month: monthKey,
          sales: order.total,
          orders: 1,
        );
      }
    }

    final sortedMonths = monthlyData.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return sortedMonths;
  }

  /// Get top selling products
  Map<String, dynamic> getTopProducts(List<OrderModel> orders) {
    final productSales = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      for (final item in order.items) {
        final productName = item.product.name;
        if (productSales.containsKey(productName)) {
          productSales[productName]!['quantity'] += item.quantity;
          productSales[productName]!['total'] += item.totalPrice;
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
      ..sort((a, b) => (b.value['total'] as num).compareTo(a.value['total'] as num));

    return {
      'products': Map.fromEntries(sortedProducts.take(10)),
      'total_products': sortedProducts.length,
    };
  }

  /// Calculate payment status distribution
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

    return distribution;
  }
}
