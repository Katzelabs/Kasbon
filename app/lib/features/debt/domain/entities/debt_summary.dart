import 'package:equatable/equatable.dart';

/// Summary statistics for debt tracking
class DebtSummary extends Equatable {
  /// Total outstanding debt amount
  final double totalDebt;

  /// Number of unique customers with debt
  final int customerCount;

  /// Total number of debt transactions
  final int transactionCount;

  /// Oldest debt date (when the oldest unpaid debt was created)
  final DateTime? oldestDebtDate;

  const DebtSummary({
    required this.totalDebt,
    required this.customerCount,
    required this.transactionCount,
    this.oldestDebtDate,
  });

  /// Create an empty summary
  const DebtSummary.empty()
      : totalDebt = 0,
        customerCount = 0,
        transactionCount = 0,
        oldestDebtDate = null;

  /// Check if there is any debt
  bool get hasDebt => transactionCount > 0;

  @override
  List<Object?> get props => [
        totalDebt,
        customerCount,
        transactionCount,
        oldestDebtDate,
      ];
}

/// Grouped debts by customer
class CustomerDebt extends Equatable {
  /// Customer name
  final String customerName;

  /// Total debt amount for this customer
  final double totalDebt;

  /// Number of debt transactions for this customer
  final int transactionCount;

  /// Transaction IDs for this customer's debts
  final List<String> transactionIds;

  const CustomerDebt({
    required this.customerName,
    required this.totalDebt,
    required this.transactionCount,
    required this.transactionIds,
  });

  @override
  List<Object?> get props => [
        customerName,
        totalDebt,
        transactionCount,
        transactionIds,
      ];
}
