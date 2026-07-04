import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../utils/format_helper.dart';

class SellerWalletScreen extends StatefulWidget {
  static const routeName = '/seller-wallet';
  const SellerWalletScreen({super.key});

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  late TabController _tabController;

  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _token =>
      Provider.of<AuthProvider>(context, listen: false).token;

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = _token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        _walletService.getBalance(token),
        _walletService.getTransactions(token),
        _walletService.getWithdrawals(token),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as double;
        _transactions = results[1] as List<Map<String, dynamic>>;
        _withdrawals = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat data saldo.';
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
          title: const Text('Tarik Saldo'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo tersedia: ${FormatHelper.formatCurrency(_balance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
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
                      if (amount > _balance) {
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
                    decoration:
                        const InputDecoration(labelText: 'Nomor Rekening'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama Pemilik Rekening'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  submitting ? null : () => Navigator.of(context).pop(),
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
                        await _walletService.requestWithdrawal(
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
                                content: Text('Penarikan saldo berhasil!')),
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
      appBar: AppBar(title: const Text('Saldo Saya')),
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
                            const Text('Saldo Tersedia',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              FormatHelper.formatCurrency(_balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _balance > 0
                                    ? _showWithdrawDialog
                                    : null,
                                icon: const Icon(Icons.arrow_upward),
                                label: const Text('Tarik Saldo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        tabs: const [
                          Tab(text: 'Riwayat Saldo'),
                          Tab(text: 'Riwayat Penarikan'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTransactionList(),
                            _buildWithdrawalList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('Belum ada mutasi saldo.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final trx = _transactions[index];
        final isCredit = trx['type'] == 'credit';
        final category = trx['category'] as String? ?? '';
        final label = category == 'sale'
            ? 'Pendapatan Penjualan'
            : category == 'withdrawal'
                ? 'Penarikan Saldo'
                : (trx['description'] ?? '-');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                isCredit ? Colors.green[100] : Colors.red[100],
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
          title: Text(label),
          subtitle: Text(trx['description'] ?? '-',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
            '${isCredit ? '+' : '-'}${FormatHelper.formatCurrency((trx['amount'] as num?)?.toDouble() ?? 0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalList() {
    if (_withdrawals.isEmpty) {
      return const Center(child: Text('Belum ada penarikan saldo.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _withdrawals.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final w = _withdrawals[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.account_balance)),
          title: Text(FormatHelper.formatCurrency(
              (w['amount'] as num?)?.toDouble() ?? 0)),
          subtitle: Text('${w['bank_name']} - ${w['bank_account_number']}'),
          trailing: Chip(
            label: Text(w['status'] ?? '-',
                style: const TextStyle(fontSize: 11, color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}