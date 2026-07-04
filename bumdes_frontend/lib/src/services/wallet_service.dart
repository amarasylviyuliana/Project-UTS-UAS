import 'api_service.dart';

class WalletService {
  Future<double> getBalance(String token) async {
    final api = ApiService(token: token);
    final response = await api.get('/wallet/balance');
    final data = response['data'] ?? {};
    return (data['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getTransactions(String token) async {
    final api = ApiService(token: token);
    final response = await api.getRaw('/wallet/transactions');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getWithdrawals(String token) async {
    final api = ApiService(token: token);
    final response = await api.getRaw('/wallet/withdrawals');
    return _extractList(response);
  }

  Future<Map<String, dynamic>> requestWithdrawal(
    String token, {
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final api = ApiService(token: token);
    final response = await api.post('/wallet/withdrawals', {
      'amount': amount,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });
    return response['data'] ?? {};
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic> && data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    }
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }
}