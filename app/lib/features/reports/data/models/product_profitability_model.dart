import '../../domain/entities/product_profitability.dart';

/// Data transfer object for ProductProfitability
class ProductProfitabilityModel extends ProductProfitability {
  const ProductProfitabilityModel({
    required super.productId,
    required super.productName,
    required super.totalProfit,
    required super.totalSold,
    required super.averageMargin,
  });

  /// Create from database query result
  factory ProductProfitabilityModel.fromQueryResult(Map<String, dynamic> row) {
    return ProductProfitabilityModel(
      productId: row['id'] as String,
      productName: row['name'] as String,
      totalProfit: (row['total_profit'] as num?)?.toDouble() ?? 0.0,
      totalSold: (row['total_sold'] as num?)?.toInt() ?? 0,
      averageMargin: (row['average_margin'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to entity
  ProductProfitability toEntity() {
    return ProductProfitability(
      productId: productId,
      productName: productName,
      totalProfit: totalProfit,
      totalSold: totalSold,
      averageMargin: averageMargin,
    );
  }
}
