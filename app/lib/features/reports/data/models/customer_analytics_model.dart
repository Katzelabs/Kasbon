import '../../domain/entities/customer_analytics.dart';
import 'report_json.dart';

/// Data transfer object for [CustomerAnalytics].
class CustomerAnalyticsModel extends CustomerAnalytics {
  const CustomerAnalyticsModel({
    required super.customerName,
    required super.transactionCount,
    required super.totalSpent,
    required super.averageTransaction,
    required super.lastTransactionAt,
    required super.outstandingDebt,
    required super.totalProfit,
    required super.lifetimeTransactionCount,
    required super.lifetimeSpent,
    required super.firstTransactionAt,
  });

  /// Create from a `get_top_customers` row.
  ///
  /// Expects:
  /// - 'customer_name': String, already trimmed by the RPC
  /// - 'transaction_count', 'lifetime_transaction_count': num
  /// - 'total_spent', 'average_transaction', 'outstanding_debt',
  ///   'total_profit', 'lifetime_spent': num
  /// - 'last_transaction_at', 'first_transaction_at': ISO 8601 String
  factory CustomerAnalyticsModel.fromQueryResult(Map<String, dynamic> row) {
    return CustomerAnalyticsModel(
      customerName: asString(row['customer_name']),
      transactionCount: asInt(row['transaction_count']),
      totalSpent: asDouble(row['total_spent']),
      averageTransaction: asDouble(row['average_transaction']),
      lastTransactionAt: asDateTimeOrNull(row['last_transaction_at']),
      outstandingDebt: asDouble(row['outstanding_debt']),
      totalProfit: asDouble(row['total_profit']),
      lifetimeTransactionCount: asInt(row['lifetime_transaction_count']),
      lifetimeSpent: asDouble(row['lifetime_spent']),
      firstTransactionAt: asDateTimeOrNull(row['first_transaction_at']),
    );
  }

  /// Convert to entity.
  CustomerAnalytics toEntity() {
    return CustomerAnalytics(
      customerName: customerName,
      transactionCount: transactionCount,
      totalSpent: totalSpent,
      averageTransaction: averageTransaction,
      lastTransactionAt: lastTransactionAt,
      outstandingDebt: outstandingDebt,
      totalProfit: totalProfit,
      lifetimeTransactionCount: lifetimeTransactionCount,
      lifetimeSpent: lifetimeSpent,
      firstTransactionAt: firstTransactionAt,
    );
  }
}
