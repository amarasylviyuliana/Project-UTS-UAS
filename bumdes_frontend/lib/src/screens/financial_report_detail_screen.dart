import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/financial_report_model.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';
import '../services/report_service.dart';
import '../services/order_service.dart';
import '../utils/format_helper.dart';

class FinancialReportDetailScreen extends StatefulWidget {
  static const routeName = '/financial-report-detail';

  const FinancialReportDetailScreen({super.key});

  @override
  State<FinancialReportDetailScreen> createState() =>
      _FinancialReportDetailScreenState();
}

class _FinancialReportDetailScreenState
    extends State<FinancialReportDetailScreen> {
  final ReportService _reportService = ReportService();
  final OrderService _orderService = OrderService();
  late DateTime _startDate;
  late DateTime _endDate;
  FinancialReportModel? _report;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String _selectedTab = 'overview'; // overview, transactions, products, insights

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = DateTime(now.year, now.month - 1, now.day);
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _loading = true);
    try {
      // Load orders
      final orders = await _orderService.getSellerOrders(auth.token!);
      setState(() => _orders = orders);

      // Calculate report from orders
      final report = _reportService.calculateFromOrders(
        orders,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('Laporan Keuangan Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('Data laporan tidak tersedia'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDateRangeCard(),
                      _buildTabNavigation(),
                      _buildTabContent(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateRangeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periode Laporan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDateRange,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    FormatHelper.formatDateRange(_startDate, _endDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A7F41),
                    ),
                  ),
                ),
                const Icon(Icons.edit, color: Color(0xFF2A7F41)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    final tabs = [
      ('Ringkasan', 'overview'),
      ('Transaksi', 'transactions'),
      ('Produk Terlaris', 'products'),
      ('Analisis', 'insights'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tab.$1),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedTab = tab.$2);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF2A7F41),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'overview':
        return _buildOverviewTab();
      case 'transactions':
        return _buildTransactionsTab();
      case 'products':
        return _buildProductsTab();
      case 'insights':
        return _buildInsightsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    if (_report == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Pendapatan',
                  FormatHelper.formatCurrency(_report!.totalRevenue),
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Pengeluaran',
                  FormatHelper.formatCurrency(_report!.totalExpense),
                  Colors.red,
                  Icons.trending_down,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Laba Bersih',
                  FormatHelper.formatCurrency(_report!.netProfit),
                  const Color(0xFF2A7F41),
                  Icons.attach_money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Margin Laba',
                  '${_report!.profitMargin.toStringAsFixed(1)}%',
                  Colors.blue,
                  Icons.percent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Order metrics
          const Text(
            'Metrik Pesanan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOrderMetricCard(
                  'Total Pesanan',
                  '${_report!.totalOrders}',
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOrderMetricCard(
                  'Pesanan Selesai',
                  '${_report!.completedOrders}',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_report!.totalOrders > 0)
            _buildOrderMetricCard(
              'Rata-rata Transaksi',
              FormatHelper.formatCurrency(_report!.totalRevenue / _report!.totalOrders),
              Colors.orange,
            ),
          const SizedBox(height: 24),
          // Summary section
          _buildSummarySection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    if (_report == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Keuangan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Pendapatan Total', FormatHelper.formatCurrency(_report!.totalRevenue)),
          const SizedBox(height: 12),
          _buildSummaryRow('Biaya Operasional', FormatHelper.formatCurrency(_report!.totalExpense)),
          const Divider(height: 20),
          _buildSummaryRow(
            'Laba Bersih',
            FormatHelper.formatCurrency(_report!.netProfit),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? const Color(0xFF2A7F41) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    if (_report == null || _report!.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Belum ada transaksi')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _report!.transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transaction = _report!.transactions[index];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: transaction.type == 'income'
                            ? Colors.green.withAlpha(25)
                            : Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        transaction.type == 'income'
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: transaction.type == 'income'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FormatHelper.formatDate(transaction.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FormatHelper.formatCurrency(transaction.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: transaction.type == 'income'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    final topProducts = _reportService.getTopProducts(_orders);
    final products = (topProducts['products'] as Map<String, dynamic>);

    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Belum ada data produk terjual')),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = products.entries.toList()[index];
              final productName = entry.key;
              final productData = entry.value as Map<String, dynamic>;
              final quantity = productData['quantity'] as int;
              final total = productData['total'] as double;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$quantity unit terjual',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          FormatHelper.formatCurrency(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2A7F41),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total / (products.values.fold<double>(0.0,
                                (prev, curr) => prev + ((curr['total'] as num?)?.toDouble() ?? 0.0)) > 0 ? products.values.fold<double>(0.0,
                                (prev, curr) => prev + ((curr['total'] as num?)?.toDouble() ?? 0.0)) : 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey.withAlpha(50),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2A7F41),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_report == null) return const SizedBox.shrink();

    final monthlySales = _reportService.getMonthlySalesData(_orders);
    final paymentStatus =
        _reportService.getPaymentStatusDistribution(_orders);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...paymentStatus.entries.map((entry) {
            final total = paymentStatus.values.fold(0, (a, b) => a + b);
            final percentage =
                total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${entry.value} ($percentage%)'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: entry.value / total,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withAlpha(50),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2A7F41),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Penjualan Bulanan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (monthlySales.isEmpty)
            const Text('Belum ada data penjualan bulanan')
          else
            ...monthlySales.map((monthData) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthData.month,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${monthData.orders} pesanan',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        FormatHelper.formatCurrency(monthData.sales),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2A7F41),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
