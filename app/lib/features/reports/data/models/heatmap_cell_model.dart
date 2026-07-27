import '../../domain/entities/heatmap_cell.dart';
import 'report_json.dart';

/// Data transfer object for [HeatmapCell].
class HeatmapCellModel extends HeatmapCell {
  const HeatmapCellModel({
    required super.dayOfWeek,
    required super.hourOfDay,
    required super.transactionCount,
    required super.revenue,
  });

  /// Create from a `get_hourly_heatmap` row.
  ///
  /// Expects:
  /// - 'day_of_week': num, ISO weekday 1 (Senin) to 7 (Minggu)
  /// - 'hour_of_day': num, 0 to 23 in shop-local time
  /// - 'transaction_count': num
  /// - 'revenue': num
  ///
  /// Both indices are clamped to their valid ranges. The RPC constrains them
  /// already, but the entity's label getters index fixed-length lists, so an
  /// unexpected value would otherwise throw a range error in the UI.
  factory HeatmapCellModel.fromQueryResult(Map<String, dynamic> row) {
    return HeatmapCellModel(
      dayOfWeek: asInt(row['day_of_week'], fallback: 1).clamp(1, 7),
      hourOfDay: asInt(row['hour_of_day']).clamp(0, 23),
      transactionCount: asInt(row['transaction_count']),
      revenue: asDouble(row['revenue']),
    );
  }

  /// Convert to entity.
  HeatmapCell toEntity() {
    return HeatmapCell(
      dayOfWeek: dayOfWeek,
      hourOfDay: hourOfDay,
      transactionCount: transactionCount,
      revenue: revenue,
    );
  }
}
