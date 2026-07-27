import 'package:equatable/equatable.dart';

/// One slice of the category distribution pie chart.
///
/// Always computed at line-item level: a transaction can span several
/// categories, so transaction totals cannot be attributed to a single slice.
/// Items whose product was deleted, or whose product has no category, are
/// grouped by the RPC into a single "Tanpa Kategori" slice with a null
/// [categoryId].
class CategorySlice extends Equatable {
  /// Category UUID, or null for the "Tanpa Kategori" bucket.
  final String? categoryId;

  /// Category name, already defaulted to 'Tanpa Kategori' by the RPC.
  final String categoryName;

  /// Hex colour string from `categories.color`, e.g. `#FF6B35`.
  final String categoryColor;

  /// Sum of line item subtotals for this category.
  final double revenue;

  /// Gross profit for this category.
  final double profit;

  /// Units sold in this category.
  final int quantitySold;

  const CategorySlice({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.revenue,
    required this.profit,
    required this.quantitySold,
  });

  /// Whether this is the catch-all bucket for uncategorised items.
  bool get isUncategorised => categoryId == null;

  /// Profit as a percentage of this slice's revenue.
  double get profitMargin {
    if (revenue == 0) return 0;
    return (profit / revenue) * 100;
  }

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        categoryColor,
        revenue,
        profit,
        quantitySold,
      ];
}

/// Chart-level helpers for a set of category slices.
extension CategorySliceX on List<CategorySlice> {
  double get totalRevenue => fold(0.0, (sum, s) => sum + s.revenue);

  double get totalProfit => fold(0.0, (sum, s) => sum + s.profit);

  /// Share of total revenue for [slice], as a percentage.
  ///
  /// Computed against the series total rather than by the RPC so the slices
  /// always sum to exactly 100%.
  double shareOf(CategorySlice slice) {
    final total = totalRevenue;
    if (total == 0) return 0;
    return (slice.revenue / total) * 100;
  }
}
