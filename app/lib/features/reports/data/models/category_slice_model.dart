import '../../domain/entities/category_slice.dart';
import 'report_json.dart';

/// Data transfer object for [CategorySlice].
class CategorySliceModel extends CategorySlice {
  const CategorySliceModel({
    required super.categoryId,
    required super.categoryName,
    required super.categoryColor,
    required super.revenue,
    required super.profit,
    required super.quantitySold,
  });

  /// Create from a `get_category_distribution` row.
  ///
  /// Expects:
  /// - 'category_id': String UUID or null for the uncategorised bucket
  /// - 'category_name': String, already defaulted to 'Tanpa Kategori'
  /// - 'category_color': String hex, already defaulted by the RPC
  /// - 'revenue', 'profit': num
  /// - 'quantity_sold': num
  factory CategorySliceModel.fromQueryResult(Map<String, dynamic> row) {
    return CategorySliceModel(
      categoryId: asStringOrNull(row['category_id']),
      categoryName: asString(row['category_name'], fallback: 'Tanpa Kategori'),
      categoryColor: asString(row['category_color'], fallback: '#9E9E9E'),
      revenue: asDouble(row['revenue']),
      profit: asDouble(row['profit']),
      quantitySold: asInt(row['quantity_sold']),
    );
  }

  /// Convert to entity.
  CategorySlice toEntity() {
    return CategorySlice(
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColor: categoryColor,
      revenue: revenue,
      profit: profit,
      quantitySold: quantitySold,
    );
  }
}
