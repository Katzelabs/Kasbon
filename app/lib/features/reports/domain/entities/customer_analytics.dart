import 'package:equatable/equatable.dart';

/// Aggregated statistics for one customer.
///
/// There is no customer table - customers are identified by
/// `transactions.customer_name`, trimmed before grouping. Grouping stays
/// case-sensitive, so "Budi" and "budi" are reported as two customers rather
/// than being silently merged.
///
/// The ranking fields cover the selected date range. The `lifetime*` fields are
/// all-time by definition and deliberately ignore the range.
class CustomerAnalytics extends Equatable {
  /// Trimmed customer name, as entered at the point of sale.
  final String customerName;

  /// Transactions within the selected range.
  final int transactionCount;

  /// Amount spent within the selected range.
  final double totalSpent;

  /// Average basket size within the selected range.
  final double averageTransaction;

  /// Most recent transaction within the selected range.
  final DateTime? lastTransactionAt;

  /// Unpaid debt within the range - debt transactions with no `debt_paid_at`.
  final double outstandingDebt;

  /// Gross profit earned from this customer within the range.
  final double totalProfit;

  /// All-time transaction count, ignoring the selected range.
  final int lifetimeTransactionCount;

  /// All-time spend, ignoring the selected range. This is the customer's
  /// lifetime value.
  final double lifetimeSpent;

  /// First ever transaction, ignoring the selected range.
  final DateTime? firstTransactionAt;

  const CustomerAnalytics({
    required this.customerName,
    required this.transactionCount,
    required this.totalSpent,
    required this.averageTransaction,
    required this.lastTransactionAt,
    required this.outstandingDebt,
    required this.totalProfit,
    required this.lifetimeTransactionCount,
    required this.lifetimeSpent,
    required this.firstTransactionAt,
  });

  bool get hasOutstandingDebt => outstandingDebt > 0;

  /// Whether this customer has bought more than once, all time.
  bool get isRepeatCustomer => lifetimeTransactionCount > 1;

  /// All-time average basket size.
  double get lifetimeAverageTransaction {
    if (lifetimeTransactionCount == 0) return 0;
    return lifetimeSpent / lifetimeTransactionCount;
  }

  /// Profit as a percentage of what this customer spent in the range.
  double get profitMargin {
    if (totalSpent == 0) return 0;
    return (totalProfit / totalSpent) * 100;
  }

  /// Days since the last purchase in the range, or null if never.
  int? daysSinceLastTransaction({DateTime? now}) {
    final last = lastTransactionAt;
    if (last == null) return null;
    return (now ?? DateTime.now()).difference(last).inDays;
  }

  /// How long this customer has been buying, or null when unknown.
  int? relationshipDays({DateTime? now}) {
    final first = firstTransactionAt;
    if (first == null) return null;
    return (now ?? DateTime.now()).difference(first).inDays;
  }

  @override
  List<Object?> get props => [
        customerName,
        transactionCount,
        totalSpent,
        averageTransaction,
        lastTransactionAt,
        outstandingDebt,
        totalProfit,
        lifetimeTransactionCount,
        lifetimeSpent,
        firstTransactionAt,
      ];
}

/// List-level helpers for customer analytics.
extension CustomerAnalyticsX on List<CustomerAnalytics> {
  double get totalSpent => fold(0.0, (sum, c) => sum + c.totalSpent);

  double get totalOutstandingDebt =>
      fold(0.0, (sum, c) => sum + c.outstandingDebt);

  /// Customers still owing money, largest debt first.
  List<CustomerAnalytics> get withOutstandingDebt {
    final debtors = where((c) => c.hasOutstandingDebt).toList()
      ..sort((a, b) => b.outstandingDebt.compareTo(a.outstandingDebt));
    return debtors;
  }

  /// Customers who have bought more than once, all time.
  List<CustomerAnalytics> get repeatCustomers =>
      where((c) => c.isRepeatCustomer).toList();
}
