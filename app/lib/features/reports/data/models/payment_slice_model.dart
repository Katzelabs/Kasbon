import '../../domain/entities/payment_slice.dart';
import '../../domain/entities/report_filter.dart';
import 'report_json.dart';

/// Data transfer object for [PaymentSlice].
class PaymentSliceModel extends PaymentSlice {
  const PaymentSliceModel({
    required super.method,
    required super.rawMethod,
    required super.transactionCount,
    required super.total,
    required super.unpaidTotal,
  });

  /// Create from a `get_payment_method_distribution` row.
  ///
  /// Expects:
  /// - 'payment_method': String ('cash' | 'transfer' | 'qris' | 'debt')
  /// - 'transaction_count': num
  /// - 'total', 'unpaid_total': num
  ///
  /// An unrecognised method is kept rather than dropped, so a value added to
  /// the database ahead of an app release still shows up in the chart.
  factory PaymentSliceModel.fromQueryResult(Map<String, dynamic> row) {
    final raw = asString(row['payment_method']);
    return PaymentSliceModel(
      method: PaymentMethod.fromWire(raw),
      rawMethod: raw,
      transactionCount: asInt(row['transaction_count']),
      total: asDouble(row['total']),
      unpaidTotal: asDouble(row['unpaid_total']),
    );
  }

  /// Convert to entity.
  PaymentSlice toEntity() {
    return PaymentSlice(
      method: method,
      rawMethod: rawMethod,
      transactionCount: transactionCount,
      total: total,
      unpaidTotal: unpaidTotal,
    );
  }
}
