import 'package:equatable/equatable.dart';

/// Payment methods supported by `transactions.payment_method`.
///
/// The wire values must stay in sync with the CHECK constraint in
/// `supabase/migrations/20260804010002_core_schema.sql`.
enum PaymentMethod {
  cash('cash', 'Tunai'),
  transfer('transfer', 'Transfer'),
  qris('qris', 'QRIS'),
  debt('debt', 'Hutang');

  const PaymentMethod(this.wireValue, this.label);

  /// Value stored in the database and sent to the RPCs.
  final String wireValue;

  /// Display label in Bahasa Indonesia.
  final String label;

  /// Resolve a database value, returning null for anything unrecognised so a
  /// future payment method does not crash an existing build.
  static PaymentMethod? fromWire(String? value) {
    if (value == null) return null;
    for (final method in PaymentMethod.values) {
      if (method.wireValue == value) return method;
    }
    return null;
  }
}

/// How a revenue figure was computed, reported back by the RPCs.
///
/// A transaction can span several categories, so transaction-level discount and
/// tax cannot be attributed to one category. When a category filter is active
/// the RPCs therefore sum matching *line item* subtotals instead of transaction
/// totals, and revenue is no longer directly comparable with an unfiltered
/// figure. The UI must label a filtered total accordingly.
enum RevenueBasis {
  /// Sum of transaction totals - includes transaction-level discount and tax.
  transaction('transaction'),

  /// Sum of matching line item subtotals - excludes transaction-level
  /// discount and tax.
  items('items');

  const RevenueBasis(this.wireValue);

  final String wireValue;

  static RevenueBasis fromWire(String? value) {
    return value == RevenueBasis.items.wireValue
        ? RevenueBasis.items
        : RevenueBasis.transaction;
  }

  /// Whether a total computed on this basis needs a disclaimer in the UI.
  bool get isPartial => this == RevenueBasis.items;
}

/// Optional filters applied to a report query.
///
/// Both fields are nullable and independent; null means "no filter".
class ReportFilter extends Equatable {
  /// Category UUID, or null for all categories.
  final String? categoryId;

  /// Payment method, or null for all methods.
  final PaymentMethod? paymentMethod;

  const ReportFilter({
    this.categoryId,
    this.paymentMethod,
  });

  /// The unfiltered default.
  static const ReportFilter none = ReportFilter();

  bool get hasCategoryFilter => categoryId != null;

  bool get hasPaymentFilter => paymentMethod != null;

  bool get isActive => hasCategoryFilter || hasPaymentFilter;

  /// Number of active filters, for a badge on the filter bar.
  int get activeCount =>
      (hasCategoryFilter ? 1 : 0) + (hasPaymentFilter ? 1 : 0);

  /// Revenue basis implied by this filter, matching what the RPCs return.
  RevenueBasis get revenueBasis =>
      hasCategoryFilter ? RevenueBasis.items : RevenueBasis.transaction;

  /// Copy with explicit clearing support - passing `clearCategory: true` sets
  /// [categoryId] to null, which a plain `copyWith(categoryId: null)` cannot
  /// express.
  ReportFilter copyWith({
    String? categoryId,
    PaymentMethod? paymentMethod,
    bool clearCategory = false,
    bool clearPayment = false,
  }) {
    return ReportFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      paymentMethod:
          clearPayment ? null : (paymentMethod ?? this.paymentMethod),
    );
  }

  @override
  List<Object?> get props => [categoryId, paymentMethod];
}
