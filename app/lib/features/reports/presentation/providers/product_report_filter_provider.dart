import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product_report_filter.dart';

/// Provider for product report sort state
final productReportFilterProvider =
    StateNotifierProvider.autoDispose<ProductReportFilterNotifier, ProductReportFilter>(
  (ref) => ProductReportFilterNotifier(),
);

/// Notifier for managing product report sort state
class ProductReportFilterNotifier extends StateNotifier<ProductReportFilter> {
  ProductReportFilterNotifier() : super(const ProductReportFilter());

  /// Set the sort option
  void setSortOption(ProductReportSortOption option) {
    state = state.copyWith(sortOption: option);
  }
}
