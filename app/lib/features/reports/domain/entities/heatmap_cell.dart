import 'package:equatable/equatable.dart';

/// Day-of-week labels indexed by ISO weekday (1 = Senin ... 7 = Minggu).
const List<String> kWeekdayLabelsShort = [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

const List<String> kWeekdayLabelsLong = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// A single (day, hour) cell of the sales heatmap.
///
/// [dayOfWeek] follows ISO numbering - 1 = Senin through 7 = Minggu - which is
/// what `get_hourly_heatmap` returns. This deliberately differs from Postgres'
/// default `DOW` (0 = Sunday) so a Monday-first Indonesian week needs no
/// remapping here, and it matches Dart's own `DateTime.weekday`.
class HeatmapCell extends Equatable {
  /// ISO weekday, 1 (Senin) to 7 (Minggu).
  final int dayOfWeek;

  /// Hour of day, 0 to 23, in the shop's local time zone.
  final int hourOfDay;

  /// Transactions recorded in this cell.
  final int transactionCount;

  /// Revenue recorded in this cell.
  final double revenue;

  const HeatmapCell({
    required this.dayOfWeek,
    required this.hourOfDay,
    required this.transactionCount,
    required this.revenue,
  });

  /// Short label, e.g. 'Sen'.
  String get dayLabelShort => kWeekdayLabelsShort[dayOfWeek - 1];

  /// Full label, e.g. 'Senin'.
  String get dayLabelLong => kWeekdayLabelsLong[dayOfWeek - 1];

  /// Hour range label, e.g. '14:00'.
  String get hourLabel => '${hourOfDay.toString().padLeft(2, '0')}:00';

  @override
  List<Object?> get props => [dayOfWeek, hourOfDay, transactionCount, revenue];
}

/// The full 7x24 heatmap, plus the peak-hour and day-of-week analytics derived
/// from it.
///
/// The RPC returns only non-empty cells, so this wrapper is what turns a sparse
/// list into a dense grid. Deriving peak hours and day-of-week comparison here
/// rather than in SQL keeps them consistent with the rendered heatmap and
/// avoids two extra round trips.
class HourlyHeatmap extends Equatable {
  /// Sparse list of non-empty cells as returned by the RPC.
  final List<HeatmapCell> cells;

  const HourlyHeatmap(this.cells);

  static const HourlyHeatmap empty = HourlyHeatmap([]);

  bool get isEmpty => cells.isEmpty;

  bool get isNotEmpty => cells.isNotEmpty;

  /// Lookup key for a cell. Hour is 0-23 so 24 spaces them without collision.
  static int _key(int dayOfWeek, int hourOfDay) => dayOfWeek * 24 + hourOfDay;

  Map<int, HeatmapCell> get _index => {
        for (final cell in cells) _key(cell.dayOfWeek, cell.hourOfDay): cell,
      };

  /// The cell at [dayOfWeek]/[hourOfDay], or null when nothing was sold then.
  HeatmapCell? cellAt(int dayOfWeek, int hourOfDay) =>
      _index[_key(dayOfWeek, hourOfDay)];

  /// Revenue at [dayOfWeek]/[hourOfDay], zero when the cell is empty.
  double revenueAt(int dayOfWeek, int hourOfDay) =>
      cellAt(dayOfWeek, hourOfDay)?.revenue ?? 0;

  /// Transaction count at [dayOfWeek]/[hourOfDay], zero when the cell is empty.
  int countAt(int dayOfWeek, int hourOfDay) =>
      cellAt(dayOfWeek, hourOfDay)?.transactionCount ?? 0;

  /// Highest revenue in any single cell. Used to scale colour intensity.
  double get maxCellRevenue => cells.isEmpty
      ? 0
      : cells.map((c) => c.revenue).reduce((a, b) => a > b ? a : b);

  /// Colour intensity for a cell, from 0.0 to 1.0, relative to the busiest
  /// cell. Returns 0 when the grid is empty.
  double intensityAt(int dayOfWeek, int hourOfDay) {
    final max = maxCellRevenue;
    if (max <= 0) return 0;
    return (revenueAt(dayOfWeek, hourOfDay) / max).clamp(0.0, 1.0);
  }

  double get totalRevenue => cells.fold(0.0, (sum, c) => sum + c.revenue);

  int get totalTransactions =>
      cells.fold(0, (sum, c) => sum + c.transactionCount);

  /// Revenue per ISO weekday, keyed 1 (Senin) to 7 (Minggu). Days with no
  /// sales are present with a value of 0, so a bar chart has all seven bars.
  Map<int, double> get revenueByDay {
    final totals = {for (var day = 1; day <= 7; day++) day: 0.0};
    for (final cell in cells) {
      totals[cell.dayOfWeek] = (totals[cell.dayOfWeek] ?? 0) + cell.revenue;
    }
    return totals;
  }

  /// Transaction count per ISO weekday, keyed 1 (Senin) to 7 (Minggu).
  Map<int, int> get transactionsByDay {
    final totals = {for (var day = 1; day <= 7; day++) day: 0};
    for (final cell in cells) {
      totals[cell.dayOfWeek] =
          (totals[cell.dayOfWeek] ?? 0) + cell.transactionCount;
    }
    return totals;
  }

  /// Revenue per hour of day, keyed 0 to 23, with empty hours at 0.
  Map<int, double> get revenueByHour {
    final totals = {for (var hour = 0; hour < 24; hour++) hour: 0.0};
    for (final cell in cells) {
      totals[cell.hourOfDay] = (totals[cell.hourOfDay] ?? 0) + cell.revenue;
    }
    return totals;
  }

  /// Transaction count per hour of day, keyed 0 to 23.
  Map<int, int> get transactionsByHour {
    final totals = {for (var hour = 0; hour < 24; hour++) hour: 0};
    for (final cell in cells) {
      totals[cell.hourOfDay] =
          (totals[cell.hourOfDay] ?? 0) + cell.transactionCount;
    }
    return totals;
  }

  /// The single busiest cell by revenue, or null when there are no sales.
  HeatmapCell? get peakCell {
    if (cells.isEmpty) return null;
    return cells.reduce((a, b) => a.revenue >= b.revenue ? a : b);
  }

  /// Busiest ISO weekday by revenue, or null when there are no sales.
  int? get busiestDay => _argMax(revenueByDay);

  /// Quietest ISO weekday by revenue among days that actually had sales.
  /// Null when there are no sales at all - a day with zero revenue is only
  /// meaningful once at least one day has some.
  int? get quietestDay {
    final withSales = Map<int, double>.fromEntries(
      revenueByDay.entries.where((e) => e.value > 0),
    );
    if (withSales.isEmpty) return null;
    return withSales.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  /// Busiest hour of day by revenue, or null when there are no sales.
  int? get busiestHour => _argMax(revenueByHour);

  /// The [count] busiest hours by revenue, most active first. Hours with no
  /// revenue are excluded, so the list can be shorter than [count].
  List<int> topHours({int count = 3}) {
    final ranked = revenueByHour.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(count).map((e) => e.key).toList();
  }

  /// Key of the largest entry, or null when every value is zero.
  static int? _argMax(Map<int, double> totals) {
    int? bestKey;
    var bestValue = 0.0;
    for (final entry in totals.entries) {
      if (entry.value > bestValue) {
        bestValue = entry.value;
        bestKey = entry.key;
      }
    }
    return bestKey;
  }

  @override
  List<Object?> get props => [cells];
}
