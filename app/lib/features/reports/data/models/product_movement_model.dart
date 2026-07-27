import '../../domain/entities/product_movement.dart';
import 'report_json.dart';

/// Data transfer object for [ProductMovement].
class ProductMovementModel extends ProductMovement {
  const ProductMovementModel({
    required super.id,
    required super.name,
    required super.sku,
    required super.currentStock,
    required super.costPrice,
    required super.stockValue,
    required super.quantitySold,
    required super.totalRevenue,
    required super.totalCogs,
    required super.totalProfit,
    required super.lastSoldAt,
    required super.turnoverRatio,
    required super.daysOfSupply,
    required super.isSlowMoving,
  });

  /// Create from a `get_product_movement` row.
  ///
  /// Expects:
  /// - 'id', 'name', 'sku': String
  /// - 'current_stock', 'quantity_sold': num
  /// - 'cost_price', 'stock_value', 'total_revenue', 'total_cogs',
  ///   'total_profit': num
  /// - 'last_sold_at': ISO 8601 String or null
  /// - 'turnover_ratio', 'days_of_supply': num or null
  /// - 'is_slow_moving': bool
  ///
  /// [turnoverRatio] and [daysOfSupply] use the nullable coercion on purpose:
  /// the RPC returns null when the ratio is undefined (no stock value, or
  /// nothing sold), which is meaningfully different from a genuine zero.
  factory ProductMovementModel.fromQueryResult(Map<String, dynamic> row) {
    return ProductMovementModel(
      id: asString(row['id']),
      name: asString(row['name']),
      sku: asString(row['sku']),
      currentStock: asInt(row['current_stock']),
      costPrice: asDouble(row['cost_price']),
      stockValue: asDouble(row['stock_value']),
      quantitySold: asInt(row['quantity_sold']),
      totalRevenue: asDouble(row['total_revenue']),
      totalCogs: asDouble(row['total_cogs']),
      totalProfit: asDouble(row['total_profit']),
      lastSoldAt: asDateTimeOrNull(row['last_sold_at']),
      turnoverRatio: asDoubleOrNull(row['turnover_ratio']),
      daysOfSupply: asDoubleOrNull(row['days_of_supply']),
      isSlowMoving: asBool(row['is_slow_moving']),
    );
  }

  /// Convert to entity.
  ProductMovement toEntity() {
    return ProductMovement(
      id: id,
      name: name,
      sku: sku,
      currentStock: currentStock,
      costPrice: costPrice,
      stockValue: stockValue,
      quantitySold: quantitySold,
      totalRevenue: totalRevenue,
      totalCogs: totalCogs,
      totalProfit: totalProfit,
      lastSoldAt: lastSoldAt,
      turnoverRatio: turnoverRatio,
      daysOfSupply: daysOfSupply,
      isSlowMoving: isSlowMoving,
    );
  }
}
