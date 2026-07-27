import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/report_filter.dart';

/// Holds the category / payment method filter shared by the report screens.
///
/// Kept separate from [dateRangeProvider] so a screen can watch one without
/// rebuilding on changes to the other.
class ReportFilterNotifier extends StateNotifier<ReportFilter> {
  ReportFilterNotifier() : super(ReportFilter.none);

  void setCategory(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);
  }

  void setPaymentMethod(PaymentMethod? method) {
    state = method == null
        ? state.copyWith(clearPayment: true)
        : state.copyWith(paymentMethod: method);
  }

  void clear() {
    state = ReportFilter.none;
  }
}

/// Provider for the active report filter.
final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilter>((ref) {
  return ReportFilterNotifier();
});
