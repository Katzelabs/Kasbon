import 'package:equatable/equatable.dart';

/// Sort options for product report
enum ProductReportSortOption {
  /// Sort by quantity sold (descending)
  quantity,

  /// Sort by total revenue (descending)
  revenue,

  /// Sort by total profit (descending)
  profit,

  /// Sort by profit margin percentage (descending)
  profitMargin;

  /// Display label for the sort option
  String get label {
    switch (this) {
      case ProductReportSortOption.quantity:
        return 'Terjual Terbanyak';
      case ProductReportSortOption.revenue:
        return 'Pendapatan Tertinggi';
      case ProductReportSortOption.profit:
        return 'Laba Tertinggi';
      case ProductReportSortOption.profitMargin:
        return 'Margin Tertinggi';
    }
  }

  /// Short label for mobile display
  String get shortLabel {
    switch (this) {
      case ProductReportSortOption.quantity:
        return 'Terjual';
      case ProductReportSortOption.revenue:
        return 'Pendapatan';
      case ProductReportSortOption.profit:
        return 'Laba';
      case ProductReportSortOption.profitMargin:
        return 'Margin';
    }
  }
}

/// Encapsulates sort option for product report
class ProductReportFilter extends Equatable {
  final ProductReportSortOption sortOption;

  const ProductReportFilter({
    this.sortOption = ProductReportSortOption.quantity,
  });

  /// Create copy with updated values
  ProductReportFilter copyWith({
    ProductReportSortOption? sortOption,
  }) {
    return ProductReportFilter(
      sortOption: sortOption ?? this.sortOption,
    );
  }

  @override
  List<Object?> get props => [sortOption];
}
