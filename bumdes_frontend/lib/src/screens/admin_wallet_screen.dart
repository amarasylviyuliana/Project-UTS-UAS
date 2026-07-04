import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../utils/format_helper.dart';
import '../widgets/paginated_list.dart';

class AdminWalletScreen extends StatefulWidget {
  static const routeName = '/admin-wallet';
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  double _platformIncome = 0;
  double _taxPercentage = 0;
  List<Map<String, dynamic>> _taxTransactions = [];
  List<Map<String, dynamic>> _storeWallets = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        _adminService.getWalletSummary(token),
        _adminService.getPlatformTaxTransactions(token),
        _adminService.getStoreWallets(token),
        _adminService.getAllWithdrawals(token),
      ]);
      if (!mounted) return;
      final summary = results[0] as Map<String, dynamic>;
      setState(() {
        _platformIncome = (summary['platform_income'] as num?)?.toDouble() ?? 0;
        _taxPercentage = (summary['tax_percentage'] as num?)?.toDouble() ?? 0;
        _taxTransactions = results[1] as List<Map<String, dynamic>>;
        _storeWallets = results[2] as List<Map<String, dynamic>>;
        _withdrawals = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data saldo & pajak.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saldo & Pajak Platform')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                          onPressed: _loadAll, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Pemasukan Admin (Biaya Admin/Pajak)',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              FormatHelper.formatCurrency(_platformIncome),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tarif saat ini: ${_taxPercentage.toStringAsFixed(0)}% dari tiap transaksi Selesai',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Riwayat Pajak'),
                          Tab(text: 'Saldo Semua Toko'),
                          Tab(text: 'Penarikan Toko'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTaxList(),
                            _buildStoreWalletList(),
                            _buildWithdrawalList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTaxList() {
    if (_taxTransactions.isEmpty) {
      return const Center(child: Text('Belum ada pemasukan pajak.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: PaginatedListView<Map<String, dynamic>>(
        items: _taxTransactions,
        pageSize: 10,
        itemBuilder: (context, trx, index) {
          final store = trx['store'] as Map<String, dynamic>?;
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.percent, color: Colors.white, size: 18),
            ),
            title: Text(store?['store_name'] ?? 'Toko tidak diketahui'),
            subtitle: Text(trx['description'] ?? '-',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              '+${FormatHelper.formatCurrency((trx['amount'] as num?)?.toDouble() ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreWalletList() {
    if (_storeWallets.isEmpty) {
      return const Center(child: Text('Belum ada saldo toko.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: PaginatedListView<Map<String, dynamic>>(
        items: _storeWallets,
        pageSize: 10,
        itemBuilder: (context, wallet, index) {
          final store = wallet['store'] as Map<String, dynamic>?;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store)),
            title: Text(store?['store_name'] ?? 'Toko tidak diketahui'),
            trailing: Text(
              FormatHelper.formatCurrency((wallet['balance'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWithdrawalList() {
    if (_withdrawals.isEmpty) {
      return const Center(child: Text('Belum ada penarikan saldo.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: PaginatedListView<Map<String, dynamic>>(
        items: _withdrawals,
        pageSize: 10,
        itemBuilder: (context, w, index) {
          final store = w['store'] as Map<String, dynamic>?;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.account_balance)),
            title: Text(store?['store_name'] ?? 'Toko tidak diketahui'),
            subtitle: Text('${w['bank_name']} - ${w['bank_account_number']}'),
            trailing: Text(
              FormatHelper.formatCurrency((w['amount'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}