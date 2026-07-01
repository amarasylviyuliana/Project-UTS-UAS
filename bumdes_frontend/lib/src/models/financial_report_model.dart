class FinancialReportModel {
  final double totalRevenue;
  final double totalExpense;
  final double netProfit;
  final int totalOrders;
  final int completedOrders;
  final List<TransactionModel> transactions;
  final String period;
  final DateTime startDate;
  final DateTime endDate;

  FinancialReportModel({
    required this.totalRevenue,
    required this.totalExpense,
    required this.netProfit,
    required this.totalOrders,
    required this.completedOrders,
    required this.transactions,
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  factory FinancialReportModel.fromJson(Map<String, dynamic> json) {
    return FinancialReportModel(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0.0,
      totalOrders: json['total_orders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      period: json['period'] as String? ?? 'Custom',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime.now(),
    );
  }

  double get profitMargin =>
      totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'total_revenue': totalRevenue,
        'total_expense': totalExpense,
        'net_profit': netProfit,
        'total_orders': totalOrders,
        'completed_orders': completedOrders,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'period': period,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };
}

class TransactionModel {
  final int id;
  final String type; // 'income', 'expense'
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String? orderId;

  TransactionModel({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.orderId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'income',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      category: json['category'] as String? ?? 'Umum',
      orderId: json['order_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'order_id': orderId,
      };
}

class MonthlySalesModel {
  final String month;
  final double sales;
  final int orders;

  MonthlySalesModel({
    required this.month,
    required this.sales,
    required this.orders,
  });

  factory MonthlySalesModel.fromJson(Map<String, dynamic> json) {
    return MonthlySalesModel(
      month: json['month'] as String? ?? '',
      sales: (json['sales'] as num?)?.toDouble() ?? 0.0,
      orders: json['orders'] as int? ?? 0,
    );
  }
}
