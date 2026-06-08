import 'package:intl/intl.dart';

class FormatHelper {
  /// Format currency dengan fallback
  static String formatCurrency(double amount) {
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
    } catch (e) {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  /// Format date dengan fallback
  static String formatDate(DateTime date, {String pattern = 'dd MMM yyyy'}) {
    try {
      return DateFormat(pattern, 'id_ID').format(date);
    } catch (e) {
      return date.toString().split(' ')[0]; // Fallback: YYYY-MM-DD
    }
  }

  /// Format date range
  static String formatDateRange(DateTime start, DateTime end) {
    try {
      final startStr = DateFormat('dd MMM', 'id_ID').format(start);
      final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(end);
      return '$startStr - $endStr';
    } catch (e) {
      return '${start.toString().split(' ')[0]} - ${end.toString().split(' ')[0]}';
    }
  }

  /// Format number dengan separator
  static String formatNumber(int number) {
    try {
      return NumberFormat('#,##0', 'id_ID').format(number);
    } catch (e) {
      return number.toString();
    }
  }

  /// Format percentage
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }
}
