/// Order Status Constants
/// Centralized definition of all order statuses used in the application
class OrderStatus {
  // Status constants
  static const String waitingPayment = 'Menunggu Pembayaran';
  static const String waitingConfirmation = 'Menunggu Konfirmasi';
  static const String confirmed = 'Dikonfirmasi';
  static const String processing = 'Diproses';
  static const String shipped = 'Dikirim';
  static const String completed = 'Selesai';
  static const String cancelled = 'Dibatalkan';

  // All statuses
  static const List<String> allStatuses = [
    waitingPayment,
    waitingConfirmation,
    confirmed,
    processing,
    shipped,
    completed,
    cancelled,
  ];

  // Buyer-facing status labels
  static final Map<String, String> buyerLabels = {
    waitingPayment: 'Menunggu Pembayaran',
    waitingConfirmation: 'Menunggu Konfirmasi Penjual',
    confirmed: 'Pesanan Dikonfirmasi',
    processing: 'Sedang Disiapkan',
    shipped: 'Sedang Dikirim',
    completed: 'Pesanan Selesai ✓',
    cancelled: 'Dibatalkan',
  };

  // Seller-facing status labels
  static final Map<String, String> sellerLabels = {
    waitingPayment: 'Menunggu Pembayaran dari Pembeli',
    waitingConfirmation: 'Menunggu Konfirmasi Pembayaran',
    confirmed: 'Pembayaran Dikonfirmasi - Siap Dikirim',
    processing: 'Sedang Disiapkan',
    shipped: 'Sudah Dikirim',
    completed: 'Pesanan Selesai',
    cancelled: 'Dibatalkan',
  };

  /// Get label for given status (buyer view)
  static String getBuyerLabel(String status) {
    return buyerLabels[status] ?? status;
  }

  /// Get label for given status (seller view)
  static String getSellerLabel(String status) {
    return sellerLabels[status] ?? status;
  }

  /// Check if status is a final status (no more changes allowed)
  static bool isFinalStatus(String status) {
    return status == completed || status == cancelled;
  }

  /// Get valid next statuses for a given current status
  static List<String> getValidNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case waitingPayment:
        // From Waiting Payment: can move to Waiting Confirmation or Cancel
        return [waitingConfirmation, cancelled];
      case waitingConfirmation:
        // From Waiting Confirmation: can only confirm to Confirmed
        return [confirmed];
      case confirmed:
        // From Confirmed: can move to Processing or directly to Shipped
        return [processing, shipped];
      case processing:
        // From Processing: can only move to Shipped
        return [shipped];
      case shipped:
        // From Shipped: can move to Completed
        return [completed];
      case completed:
      case cancelled:
        // Final statuses: no transitions allowed
        return [];
      default:
        return [];
    }
  }

  /// Check if transition is valid
  static bool isValidTransition(String from, String to) {
    return getValidNextStatuses(from).contains(to);
  }

  /// Get status category for grouping
  /// Useful for dashboard summary
  static String getCategory(String status) {
    switch (status) {
      case waitingPayment:
      case waitingConfirmation:
        return 'Menunggu';
      case confirmed:
      case processing:
      case shipped:
        return 'Sedang Berjalan';
      case completed:
        return 'Selesai';
      case cancelled:
        return 'Dibatalkan';
      default:
        return 'Lainnya';
    }
  }

  /// Get all statuses in a category
  static List<String> getStatusesByCategory(String category) {
    switch (category) {
      case 'Menunggu':
        return [waitingPayment, waitingConfirmation];
      case 'Sedang Berjalan':
        return [confirmed, processing, shipped];
      case 'Selesai':
        return [completed];
      case 'Dibatalkan':
        return [cancelled];
      default:
        return [];
    }
  }

  /// Get action button text for a given status (seller perspective)
  static String getSellerActionText(String status) {
    switch (status) {
      case waitingConfirmation:
        return 'Konfirmasi Pesanan';
      case confirmed:
        return 'Pesanan Sedang Disiapkan';
      case processing:
        return 'Kirim Pesanan';
      case shipped:
        return 'Tandai Selesai';
      default:
        return '';
    }
  }

  /// Check if buyer can perform receipt confirmation
  static bool canBuyerConfirmReceipt(String status) {
    return status == shipped;
  }

  /// Check if buyer can cancel order
  static bool canBuyerCancel(String status) {
    return status == waitingPayment;
  }

  /// Check if seller can confirm payment
  static bool canSellerConfirmPayment(String status) {
    return status == waitingConfirmation;
  }
}
