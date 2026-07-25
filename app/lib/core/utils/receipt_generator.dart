import '../../features/receipt/domain/entities/shop_settings.dart';
import '../../features/transactions/domain/entities/transaction.dart';
import '../../features/transactions/domain/entities/transaction_item.dart';
import '../constants/app_constants.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

/// Utility class for generating text-based receipts
///
/// Generates 42-character wide receipts compatible with
/// thermal printers (58mm paper) and text-based sharing.
class ReceiptGenerator {
  ReceiptGenerator._();

  /// Receipt width in characters (thermal printer standard for 58mm paper)
  static const int receiptWidth = 42;

  /// Generate a complete receipt from transaction and shop settings
  static String generate({
    required Transaction transaction,
    required ShopSettings shopSettings,
  }) {
    final buffer = StringBuffer();

    // Header section
    buffer.writeln(_dividerDouble());
    buffer.write(_generateHeader(shopSettings));
    buffer.writeln(_dividerDouble());

    // Transaction info
    buffer.write(_generateTransactionInfo(transaction));
    buffer.writeln(_dividerSingle());

    // Items section
    buffer.writeln(_formatColumnHeader());
    buffer.writeln(_dividerSingle());
    for (final item in transaction.items) {
      buffer.write(_generateItemLines(item));
    }
    buffer.writeln(_dividerSingle());

    // Payment summary
    buffer.write(_generatePaymentSummary(transaction));
    buffer.writeln(_dividerDouble());

    // Footer
    buffer.write(_generateFooter(shopSettings));
    buffer.writeln(_dividerDouble());

    return buffer.toString();
  }

  /// Generate header with shop info
  static String _generateHeader(ShopSettings settings) {
    final buffer = StringBuffer();

    // Shop name (centered, uppercase)
    buffer.writeln(_centerText(settings.name.toUpperCase()));

    // Address (if exists)
    if (settings.address != null && settings.address!.isNotEmpty) {
      buffer.writeln(_centerText(settings.address!));
    }

    // Phone (if exists)
    if (settings.phone != null && settings.phone!.isNotEmpty) {
      buffer.writeln(_centerText(settings.phone!));
    }

    // Custom header (if exists)
    if (settings.receiptHeader != null && settings.receiptHeader!.isNotEmpty) {
      buffer.writeln(_centerText(settings.receiptHeader!));
    }

    return buffer.toString();
  }

  /// Generate transaction info section
  static String _generateTransactionInfo(Transaction transaction) {
    final buffer = StringBuffer();

    buffer.writeln('No: ${transaction.transactionNumber}');
    buffer.writeln('Tanggal: ${_formatDateTime(transaction.transactionDate)}');

    if (transaction.cashierName != null &&
        transaction.cashierName!.isNotEmpty) {
      buffer.writeln('Kasir: ${transaction.cashierName}');
    }

    if (transaction.customerName != null &&
        transaction.customerName!.isNotEmpty) {
      buffer.writeln('Pelanggan: ${transaction.customerName}');
    }

    return buffer.toString();
  }

  /// Format column header for items section
  static String _formatColumnHeader() {
    // Left-align "Item", right-align "Qty" and "Subtotal"
    const item = 'Item';
    const qty = 'Qty';
    const subtotal = 'Subtotal';

    // Calculate spacing
    const qtyStart = receiptWidth - 6 - subtotal.length;
    const itemPadding = qtyStart - item.length;

    return '$item${' ' * itemPadding}$qty${' ' * 2}$subtotal';
  }

  /// Generate lines for a single item
  /// Uses two-line format:
  /// Line 1: Product name (truncated if needed)
  /// Line 2: "  qty x price" (left) and subtotal (right)
  static String _generateItemLines(TransactionItem item) {
    final buffer = StringBuffer();

    // Line 1: Product name (truncate if too long)
    final name = _truncateText(item.productName, receiptWidth);
    buffer.writeln(name);

    // Line 2: "  qty x price" on left, subtotal on right
    final qtyPrice = '  ${item.quantity} x ${_formatCurrency(item.sellingPrice)}';
    final subtotal = _formatCurrency(item.subtotal);

    final spacing = receiptWidth - qtyPrice.length - subtotal.length;
    buffer.writeln('$qtyPrice${' ' * spacing.clamp(1, receiptWidth)}$subtotal');

    return buffer.toString();
  }

  /// Generate payment summary section
  static String _generatePaymentSummary(Transaction transaction) {
    final buffer = StringBuffer();

    // Subtotal
    buffer.writeln(_formatSummaryLine('Subtotal', transaction.subtotal));

    // Discount (if any)
    if (transaction.discountAmount > 0) {
      buffer.writeln(_formatSummaryLine('Diskon', -transaction.discountAmount));
    }

    // Divider before total
    buffer.writeln(_dividerSingle());

    // Total (emphasized)
    buffer.writeln(_formatSummaryLine('TOTAL', transaction.total));

    // Divider after total
    buffer.writeln(_dividerSingle());

    // Payment status for debt transactions
    if (transaction.isDebt) {
      buffer.writeln(_centerText('** HUTANG **'));
      buffer.writeln(_formatSummaryLineString('Status', 'Belum Lunas'));
    } else {
      // Cash received and change for paid transactions
      if (transaction.cashReceived != null && transaction.cashReceived! > 0) {
        buffer.writeln(
            _formatSummaryLine('Uang Diterima', transaction.cashReceived!));
        buffer.writeln(
            _formatSummaryLine('Kembalian', transaction.cashChange ?? 0));
      }
    }

    // Payment method
    buffer.writeln(_formatSummaryLineString('Metode', transaction.paymentMethod.label));

    return buffer.toString();
  }

  /// Generate footer section
  static String _generateFooter(ShopSettings settings) {
    final buffer = StringBuffer();

    // Custom footer or default thank you message
    if (settings.receiptFooter != null && settings.receiptFooter!.isNotEmpty) {
      buffer.writeln(_centerText(settings.receiptFooter!));
    } else {
      buffer.writeln(_centerText('Terima kasih atas kunjungannya!'));
    }

    // App branding
    buffer.writeln(_centerText('Powered by ${AppConstants.appName}'));

    return buffer.toString();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Create a summary line with label and numeric value
  static String _formatSummaryLine(String label, double value) {
    final formattedValue = _formatCurrency(value.abs());
    final prefix = value < 0 ? '-' : '';
    return _formatLabelValuePair(label, '$prefix$formattedValue');
  }

  /// Create a summary line with label and string value
  static String _formatSummaryLineString(String label, String value) {
    return _formatLabelValuePair(label, value);
  }

  /// Format a label-value pair with label on left and value right-aligned
  static String _formatLabelValuePair(String label, String value) {
    final spacing = receiptWidth - label.length - value.length - 2;
    return '$label:${' ' * spacing.clamp(1, receiptWidth)}$value';
  }

  /// Double-line divider (used for header/footer)
  static String _dividerDouble() => '=' * receiptWidth;

  /// Single-line divider (used for sections)
  static String _dividerSingle() => '-' * receiptWidth;

  /// Center text within receipt width
  static String _centerText(String text) {
    if (text.length >= receiptWidth) {
      return text.substring(0, receiptWidth);
    }
    final leftPadding = (receiptWidth - text.length) ~/ 2;
    final rightPadding = receiptWidth - leftPadding - text.length;
    return '${' ' * leftPadding}$text${' ' * rightPadding}';
  }

  /// Truncate text with ellipsis if too long
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Format currency value
  static String _formatCurrency(double value) {
    return CurrencyFormatter.format(value);
  }

  /// Format date and time for receipt display
  /// Format: "02 Jan 2026, 14:30"
  static String _formatDateTime(DateTime date) {
    return '${DateFormatter.formatDayMonth(date)} ${date.year}, ${DateFormatter.formatTime(date)}';
  }
}
