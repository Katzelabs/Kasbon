import '../../domain/entities/product_report.dart';

/// Data transfer object for ProductReport
class ProductReportModel extends ProductReport {
  const ProductReportModel({
    required super.productId,
    required super.productName,
    required super.quantitySold,
    required super.totalRevenue,
    required super.totalProfit,
  });

  /// Create from database query result
  factory ProductReportModel.fromQueryResult(Map<String, dynamic> row) {
    return ProductReportModel(
      productId: row['id'] as String? ?? '',
      productName: row['name'] as String? ?? '',
      quantitySold: (row['quantity_sold'] as num?)?.toInt() ?? 0,
      totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (row['total_profit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to entity
  ProductReport toEntity() {
    return ProductReport(
      productId: productId,
      productName: productName,
      quantitySold: quantitySold,
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
    );
  }
}
