import 'package:equatable/equatable.dart';

import 'report_filter.dart';

/// One slice of the payment method distribution pie chart.
///
/// Computed at transaction level. Unlike the sales and profit reports, `debt`
/// is kept as its own slice here rather than folded into revenue, so the shop
/// can see how much of its turnover is unpaid.
class PaymentSlice extends Equatable {
  /// Parsed payment method, or null if the database holds a value this build
  /// does not recognise.
  final PaymentMethod? method;

  /// Raw wire value, retained so an unrecognised method can still be displayed.
  final String rawMethod;

  /// Number of transactions using this method.
  final int transactionCount;

  /// Sum of transaction totals for this method.
  final double total;

  /// Portion of [total] still unpaid - debt transactions with no
  /// `debt_paid_at`. Zero for every method other than `debt`.
  final double unpaidTotal;

  const PaymentSlice({
    required this.method,
    required this.rawMethod,
    required this.transactionCount,
    required this.total,
    required this.unpaidTotal,
  });

  /// Display label, falling back to the raw value for an unknown method.
  String get label => method?.label ?? rawMethod;

  /// Portion of [total] already collected.
  double get paidTotal => total - unpaidTotal;

  bool get hasOutstandingDebt => unpaidTotal > 0;

  /// Average transaction value for this method.
  double get averageTransactionValue {
    if (transactionCount == 0) return 0;
    return total / transactionCount;
  }

  @override
  List<Object?> get props => [
        method,
        rawMethod,
        transactionCount,
        total,
        unpaidTotal,
      ];
}

/// Chart-level helpers for a set of payment slices.
extension PaymentSliceX on List<PaymentSlice> {
  double get totalRevenue => fold(0.0, (sum, s) => sum + s.total);

  /// Total still owed to the shop across every method.
  double get totalUnpaid => fold(0.0, (sum, s) => sum + s.unpaidTotal);

  int get totalTransactions => fold(0, (sum, s) => sum + s.transactionCount);

  /// Share of total revenue for [slice], as a percentage.
  double shareOf(PaymentSlice slice) {
    final total = totalRevenue;
    if (total == 0) return 0;
    return (slice.total / total) * 100;
  }
}
