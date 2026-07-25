import 'package:equatable/equatable.dart';

/// Daily sales entity for chart visualization
class DailySales extends Equatable {
  /// The date of the sales data
  final DateTime date;

  /// Total revenue for the day
  final double revenue;

  /// Number of transactions for the day
  final int transactionCount;

  const DailySales({
    required this.date,
    required this.revenue,
    required this.transactionCount,
  });

  /// Average transaction value for the day
  double get averageTransactionValue {
    if (transactionCount == 0) return 0;
    return revenue / transactionCount;
  }

  @override
  List<Object?> get props => [date, revenue, transactionCount];
}
