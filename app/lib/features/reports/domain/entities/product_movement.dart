import 'package:equatable/equatable.dart';

/// Inventory movement statistics for one active product.
///
/// `get_product_movement` returns a row for every active product, including
/// those with no sales at all - those are exactly what the slow-moving report
/// is for. Both the turnover ranking and the slow-moving list are derived from
/// this single payload.
class ProductMovement extends Equatable {
  final String id;
  final String name;
  final String sku;

  /// Stock on hand right now, not at the end of the range.
  final int currentStock;

  /// Current cost price per unit.
  final double costPrice;

  /// Current inventory value, `currentStock * costPrice`.
  final double stockValue;

  /// Units sold within the selected range.
  final int quantitySold;

  /// Revenue within the range, from line item subtotals.
  final double totalRevenue;

  /// Cost of goods sold within the range.
  final double totalCogs;

  /// Gross profit within the range.
  final double totalProfit;

  /// Most recent sale within the range, or null if it did not sell.
  final DateTime? lastSoldAt;

  /// COGS divided by current inventory value.
  ///
  /// This approximates the textbook "COGS / average inventory": the schema
  /// keeps no historical stock levels, so a true period average is not
  /// computable. Null when the product currently carries no stock value, since
  /// the ratio would divide by zero.
  final double? turnoverRatio;

  /// How many days the current stock would last at the range's average sales
  /// rate. Null when nothing sold, because the rate would be zero.
  final double? daysOfSupply;

  /// Whether the RPC classified this product as slow-moving: stocked but with
  /// no sales in the range, or carrying more than the threshold number of days
  /// of supply at the current rate.
  final bool isSlowMoving;

  const ProductMovement({
    required this.id,
    required this.name,
    required this.sku,
    required this.currentStock,
    required this.costPrice,
    required this.stockValue,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalProfit,
    required this.lastSoldAt,
    required this.turnoverRatio,
    required this.daysOfSupply,
    required this.isSlowMoving,
  });

  /// Stocked but sold nothing at all in the range - the worst case, and worth
  /// distinguishing from merely overstocked in the UI.
  bool get isDeadStock => quantitySold == 0 && currentStock > 0;

  /// Out of stock and therefore unable to sell.
  bool get isOutOfStock => currentStock == 0;

  /// Capital currently tied up in this product while it is not moving.
  double get tiedUpCapital => isSlowMoving ? stockValue : 0;

  /// Gross margin on what actually sold in the range.
  double get profitMargin {
    if (totalRevenue == 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }

  /// Average units sold per day over a range of [rangeDays] days.
  double averageDailySales(double rangeDays) {
    if (rangeDays <= 0) return 0;
    return quantitySold / rangeDays;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        currentStock,
        costPrice,
        stockValue,
        quantitySold,
        totalRevenue,
        totalCogs,
        totalProfit,
        lastSoldAt,
        turnoverRatio,
        daysOfSupply,
        isSlowMoving,
      ];
}

/// List-level helpers deriving both report views from one payload.
extension ProductMovementX on List<ProductMovement> {
  /// Fastest-moving products first. Products with a null turnover ratio (no
  /// stock value) sort last rather than being dropped.
  List<ProductMovement> get byTurnoverDesc {
    final sorted = List<ProductMovement>.from(this)
      ..sort((a, b) {
        final at = a.turnoverRatio;
        final bt = b.turnoverRatio;
        if (at == null && bt == null) return a.name.compareTo(b.name);
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    return sorted;
  }

  /// Slow movers, worst first: dead stock ahead of merely overstocked, then by
  /// the capital each one is tying up.
  List<ProductMovement> get slowMoving {
    final slow = where((p) => p.isSlowMoving).toList()
      ..sort((a, b) {
        if (a.isDeadStock != b.isDeadStock) return a.isDeadStock ? -1 : 1;
        return b.stockValue.compareTo(a.stockValue);
      });
    return slow;
  }

  /// Products that sold nothing at all in the range but still hold stock.
  List<ProductMovement> get deadStock => where((p) => p.isDeadStock).toList();

  /// Total capital tied up in slow-moving stock.
  double get tiedUpCapital => fold(0.0, (sum, p) => sum + p.tiedUpCapital);

  /// Value of all inventory currently on hand.
  double get totalStockValue => fold(0.0, (sum, p) => sum + p.stockValue);

  /// Total cost of goods sold across the range.
  double get totalCogs => fold(0.0, (sum, p) => sum + p.totalCogs);
}
