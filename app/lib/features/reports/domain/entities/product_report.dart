import 'package:equatable/equatable.dart';

/// Product report entity with sales statistics
class ProductReport extends Equatable {
  /// Product ID
  final String productId;

  /// Product name
  final String productName;

  /// Total quantity sold
  final int quantitySold;

  /// Total revenue from this product
  final double totalRevenue;

  /// Total profit from this product
  final double totalProfit;

  const ProductReport({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalProfit,
  });

  /// Calculated profit margin percentage
  double get profitMargin {
    if (totalRevenue == 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }

  /// Average price per unit sold
  double get averagePrice {
    if (quantitySold == 0) return 0;
    return totalRevenue / quantitySold;
  }

  /// Average profit per unit sold
  double get averageProfitPerUnit {
    if (quantitySold == 0) return 0;
    return totalProfit / quantitySold;
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        quantitySold,
        totalRevenue,
        totalProfit,
      ];
}
