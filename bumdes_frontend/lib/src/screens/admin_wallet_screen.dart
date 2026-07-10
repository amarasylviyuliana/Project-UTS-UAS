import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
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
  double _platformBalance = 0;
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

  String? get _token => Provider.of<AuthProvider>(context, listen: false).token;

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = _token;
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
        // Fallback ke platform_income kalau backend lama belum mengirim platform_balance.
        _platformBalance =
            (summary['platform_balance'] as num?)?.toDouble() ??
            _platformIncome;
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

  Future<void> _showWithdrawDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    bool submitting = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tarik Saldo Platform'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo tersedia: ${FormatHelper.formatCurrency(_platformBalance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saldo ini berasal dari akumulasi biaya admin/pajak seluruh transaksi penjual.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Penarikan',
                      prefixText: 'Rp ',
                    ),
                    validator: (v) {
                      final amount = double.tryParse(v ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Masukkan nominal yang valid';
                      }
                      if (amount > _platformBalance) {
                        return 'Saldo tidak mencukupi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: bankNameController,
                    decoration: const InputDecoration(labelText: 'Nama Bank'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Rekening',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik Rekening',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        errorText = null;
                      });
                      try {
                        final token = _token;
                        if (token == null) return;
                        await _adminService.requestPlatformWithdrawal(
                          token,
                          amount: double.parse(amountController.text),
                          bankName: bankNameController.text,
                          bankAccountNumber: accountNumberController.text,
                          bankAccountName: accountNameController.text,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                        await _loadAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Penarikan saldo platform berhasil!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          submitting = false;
                          errorText = e is ApiException
                              ? e.message
                              : 'Gagal memproses penarikan.';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tarik Sekarang'),
            ),
          ],
        ),
      ),
    );
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
                    onPressed: _loadAll,
                    child: const Text('Coba Lagi'),
                  ),
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
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo Platform Tersedia',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          FormatHelper.formatCurrency(_platformBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total pemasukan sepanjang waktu: ${FormatHelper.formatCurrency(_platformIncome)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tarif saat ini: ${_taxPercentage.toStringAsFixed(0)}% dari tiap transaksi Selesai (dipotong dari saldo penjual sebagai biaya admin)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _platformBalance > 0
                                ? _showWithdrawDialog
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                            label: const Text('Tarik Saldo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2E7D32),
                            ),
                          ),
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
                      Tab(text: 'Penarikan'),
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
            title: Text(store?['store_name'] ?? 'Biaya Admin Platform'),
            subtitle: Text(
              trx['description'] ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '+${FormatHelper.formatCurrency((trx['amount'] as num?)?.toDouble() ?? 0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
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
              FormatHelper.formatCurrency(
                (wallet['balance'] as num?)?.toDouble() ?? 0,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
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
          final isPlatform = store == null;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isPlatform ? Colors.blue[100] : null,
              child: Icon(
                isPlatform
                    ? Icons.account_balance_wallet
                    : Icons.account_balance,
                color: isPlatform ? Colors.blue : null,
              ),
            ),
            title: Text(
              isPlatform
                  ? 'Penarikan Saldo Platform (Admin)'
                  : (store['store_name'] ?? 'Toko tidak diketahui'),
            ),
            subtitle: Text('${w['bank_name']} - ${w['bank_account_number']}'),
            trailing: Text(
              FormatHelper.formatCurrency(
                (w['amount'] as num?)?.toDouble() ?? 0,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
