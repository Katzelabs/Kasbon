import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/reports/data/models/category_slice_model.dart';
import 'package:kasbon_pos/features/reports/data/models/customer_analytics_model.dart';
import 'package:kasbon_pos/features/reports/data/models/heatmap_cell_model.dart';
import 'package:kasbon_pos/features/reports/data/models/payment_slice_model.dart';
import 'package:kasbon_pos/features/reports/data/models/product_movement_model.dart';
import 'package:kasbon_pos/features/reports/data/models/sales_trend_point_model.dart';
import 'package:kasbon_pos/features/reports/domain/entities/report_filter.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';

/// The payloads below are copied verbatim from the RPCs running against
/// `supabase/seed.sql`, so these tests pin the real wire format rather than an
/// assumed one.
void main() {
  group('SalesTrendPointModel.fromQueryResult', () {
    test('parses a real get_sales_trend row', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'profit': 29000.00,
        'revenue': 133000.00,
        'items_sold': 13,
        'granularity': 'day',
        'bucket_start': '2026-07-22',
        'revenue_basis': 'transaction',
        'transaction_count': 1,
      });

      expect(model.bucketStart, DateTime(2026, 7, 22));
      expect(model.granularity, TrendGranularity.day);
      expect(model.revenue, 133000.0);
      expect(model.profit, 29000.0);
      expect(model.itemsSold, 13);
      expect(model.transactionCount, 1);
      expect(model.revenueBasis, RevenueBasis.transaction);
    });

    test('maps a category-filtered row to the items revenue basis', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-01',
        'granularity': 'month',
        'revenue': 119000.00,
        'profit': 39000.00,
        'items_sold': 18,
        'transaction_count': 4,
        'revenue_basis': 'items',
      });

      expect(model.revenueBasis, RevenueBasis.items);
      expect(model.revenueBasis.isPartial, isTrue);
      expect(model.granularity, TrendGranularity.month);
    });

    test('parses a bucket_start without shifting it across a time zone', () {
      // The RPC has already converted to shop-local time, so parsing must not
      // apply a second conversion and slide the bucket to the previous day.
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-31',
        'granularity': 'day',
        'revenue': 0,
        'profit': 0,
        'items_sold': 0,
        'transaction_count': 0,
      });

      expect(model.bucketStart.year, 2026);
      expect(model.bucketStart.month, 7);
      expect(model.bucketStart.day, 31);
    });

    test('falls back to day granularity for an unknown value', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-01',
        'granularity': 'fortnight',
        'revenue': 0,
        'profit': 0,
        'items_sold': 0,
        'transaction_count': 0,
      });

      expect(model.granularity, TrendGranularity.day);
    });

    test('tolerates decimals arriving as strings', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-01',
        'granularity': 'day',
        'revenue': '133000.00',
        'profit': '29000.00',
        'items_sold': '13',
        'transaction_count': '1',
      });

      expect(model.revenue, 133000.0);
      expect(model.profit, 29000.0);
      expect(model.itemsSold, 13);
    });

    test('computes profit margin and average transaction value', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-22',
        'granularity': 'day',
        'revenue': 200000.0,
        'profit': 50000.0,
        'items_sold': 10,
        'transaction_count': 4,
      });

      expect(model.profitMargin, 25.0);
      expect(model.averageTransactionValue, 50000.0);
    });

    test('does not divide by zero on an empty bucket', () {
      final model = SalesTrendPointModel.fromQueryResult(const {
        'bucket_start': '2026-07-22',
        'granularity': 'day',
        'revenue': 0,
        'profit': 0,
        'items_sold': 0,
        'transaction_count': 0,
      });

      expect(model.profitMargin, 0);
      expect(model.averageTransactionValue, 0);
    });
  });

  group('CategorySliceModel.fromQueryResult', () {
    test('parses a real get_category_distribution row', () {
      final model = CategorySliceModel.fromQueryResult(const {
        'profit': 166000.00,
        'revenue': 682500.00,
        'category_id': 'c1000000-0000-0000-0000-000000000001',
        'category_name': 'Makanan',
        'quantity_sold': 82,
        'category_color': '#FF6B35',
      });

      expect(model.categoryId, 'c1000000-0000-0000-0000-000000000001');
      expect(model.categoryName, 'Makanan');
      expect(model.categoryColor, '#FF6B35');
      expect(model.revenue, 682500.0);
      expect(model.isUncategorised, isFalse);
    });

    test('handles the null-category bucket', () {
      final model = CategorySliceModel.fromQueryResult(const {
        'profit': 24000.00,
        'revenue': 84000.00,
        'category_id': null,
        'category_name': 'Tanpa Kategori',
        'quantity_sold': 3,
        'category_color': '#9E9E9E',
      });

      expect(model.categoryId, isNull);
      expect(model.isUncategorised, isTrue);
      expect(model.categoryName, 'Tanpa Kategori');
    });
  });

  group('PaymentSliceModel.fromQueryResult', () {
    test('parses a real cash row', () {
      final model = PaymentSliceModel.fromQueryResult(const {
        'total': 928400.00,
        'unpaid_total': 0,
        'payment_method': 'cash',
        'transaction_count': 16,
      });

      expect(model.method, PaymentMethod.cash);
      expect(model.label, 'Tunai');
      expect(model.total, 928400.0);
      expect(model.unpaidTotal, 0);
      expect(model.paidTotal, 928400.0);
      expect(model.hasOutstandingDebt, isFalse);
    });

    test('parses a debt row with an unpaid balance', () {
      final model = PaymentSliceModel.fromQueryResult(const {
        'total': 397000.00,
        'unpaid_total': 295000.00,
        'payment_method': 'debt',
        'transaction_count': 5,
      });

      expect(model.method, PaymentMethod.debt);
      expect(model.label, 'Hutang');
      expect(model.unpaidTotal, 295000.0);
      expect(model.paidTotal, 102000.0);
      expect(model.hasOutstandingDebt, isTrue);
    });

    test('keeps an unrecognised payment method instead of dropping it', () {
      // A method added to the database ahead of an app release must still
      // appear in the chart rather than silently vanishing from the totals.
      final model = PaymentSliceModel.fromQueryResult(const {
        'total': 50000.00,
        'unpaid_total': 0,
        'payment_method': 'crypto',
        'transaction_count': 1,
      });

      expect(model.method, isNull);
      expect(model.rawMethod, 'crypto');
      expect(model.label, 'crypto');
      expect(model.total, 50000.0);
    });
  });

  group('HeatmapCellModel.fromQueryResult', () {
    test('parses a real get_hourly_heatmap cell', () {
      final model = HeatmapCellModel.fromQueryResult(const {
        'revenue': 268500.00,
        'day_of_week': 5,
        'hour_of_day': 14,
        'transaction_count': 4,
      });

      expect(model.dayOfWeek, 5);
      expect(model.hourOfDay, 14);
      expect(model.dayLabelShort, 'Jum');
      expect(model.dayLabelLong, 'Jumat');
      expect(model.hourLabel, '14:00');
      expect(model.revenue, 268500.0);
    });

    test('labels Monday as ISO day 1 and Sunday as 7', () {
      HeatmapCellModel cell(int day) => HeatmapCellModel.fromQueryResult({
            'day_of_week': day,
            'hour_of_day': 9,
            'transaction_count': 1,
            'revenue': 1000,
          });

      expect(cell(1).dayLabelLong, 'Senin');
      expect(cell(7).dayLabelLong, 'Minggu');
    });

    test('pads a single-digit hour label', () {
      final model = HeatmapCellModel.fromQueryResult(const {
        'day_of_week': 3,
        'hour_of_day': 7,
        'transaction_count': 1,
        'revenue': 1000,
      });

      expect(model.hourLabel, '07:00');
    });

    test('clamps out-of-range indices so label lookup cannot throw', () {
      final low = HeatmapCellModel.fromQueryResult(const {
        'day_of_week': 0,
        'hour_of_day': -3,
        'transaction_count': 0,
        'revenue': 0,
      });
      final high = HeatmapCellModel.fromQueryResult(const {
        'day_of_week': 9,
        'hour_of_day': 99,
        'transaction_count': 0,
        'revenue': 0,
      });

      expect(low.dayOfWeek, 1);
      expect(low.hourOfDay, 0);
      expect(high.dayOfWeek, 7);
      expect(high.hourOfDay, 23);
      expect(() => low.dayLabelLong, returnsNormally);
      expect(() => high.dayLabelLong, returnsNormally);
    });
  });

  group('CustomerAnalyticsModel.fromQueryResult', () {
    test('parses a real get_top_customers row', () {
      final model = CustomerAnalyticsModel.fromQueryResult(const {
        'total_spent': 133000.00,
        'total_profit': 29000.00,
        'customer_name': 'Bu Siti',
        'lifetime_spent': 133000.00,
        'outstanding_debt': 133000.00,
        'transaction_count': 1,
        'average_transaction': 133000.000000000000,
        'last_transaction_at': '2026-07-22T07:33:30.959438+00:00',
        'first_transaction_at': '2026-07-22T07:33:30.959438+00:00',
        'lifetime_transaction_count': 1,
      });

      expect(model.customerName, 'Bu Siti');
      expect(model.totalSpent, 133000.0);
      expect(model.outstandingDebt, 133000.0);
      expect(model.hasOutstandingDebt, isTrue);
      expect(model.isRepeatCustomer, isFalse);
      expect(model.lastTransactionAt, isNotNull);
      expect(model.lastTransactionAt!.isUtc, isFalse,
          reason: 'timestamps are converted to local time for display');
    });

    test('flags a repeat customer from the lifetime count', () {
      final model = CustomerAnalyticsModel.fromQueryResult(const {
        'customer_name': 'Pak Ahmad',
        'transaction_count': 1,
        'total_spent': 52000.00,
        'average_transaction': 52000.00,
        'last_transaction_at': '2026-07-15T07:33:30.959438+00:00',
        'outstanding_debt': 0,
        'total_profit': 16000.00,
        'lifetime_transaction_count': 4,
        'lifetime_spent': 210000.00,
        'first_transaction_at': '2026-01-15T07:33:30.959438+00:00',
      });

      expect(model.isRepeatCustomer, isTrue);
      expect(model.lifetimeAverageTransaction, 52500.0);
      expect(model.hasOutstandingDebt, isFalse);
    });

    test('handles a null timestamp without throwing', () {
      final model = CustomerAnalyticsModel.fromQueryResult(const {
        'customer_name': 'Tanpa Tanggal',
        'transaction_count': 0,
        'total_spent': 0,
        'average_transaction': 0,
        'last_transaction_at': null,
        'outstanding_debt': 0,
        'total_profit': 0,
        'lifetime_transaction_count': 0,
        'lifetime_spent': 0,
        'first_transaction_at': null,
      });

      expect(model.lastTransactionAt, isNull);
      expect(model.daysSinceLastTransaction(), isNull);
      expect(model.relationshipDays(), isNull);
      expect(model.lifetimeAverageTransaction, 0);
    });

    test('computes days since last transaction against a fixed now', () {
      final model = CustomerAnalyticsModel.fromQueryResult(const {
        'customer_name': 'Mbak Dewi',
        'transaction_count': 1,
        'total_spent': 57000.00,
        'average_transaction': 57000.00,
        'last_transaction_at': '2026-06-29T00:00:00+00:00',
        'outstanding_debt': 0,
        'total_profit': 13000.00,
        'lifetime_transaction_count': 1,
        'lifetime_spent': 57000.00,
        'first_transaction_at': '2026-06-29T00:00:00+00:00',
      });

      final now = DateTime.parse('2026-07-09T00:00:00Z');
      expect(model.daysSinceLastTransaction(now: now), 10);
    });
  });

  group('ProductMovementModel.fromQueryResult', () {
    test('parses a real get_product_movement row', () {
      final model = ProductMovementModel.fromQueryResult(const {
        'id': 'd1000000-0000-0000-0000-000000000009',
        'sku': 'AQU-00009',
        'name': 'Air Mineral 600ml',
        'cost_price': 2500.00,
        'total_cogs': 25000.00,
        'stock_value': 115000.00,
        'last_sold_at': '2026-07-25T15:14:30.738+00:00',
        'total_profit': 15000.00,
        'current_stock': 46,
        'quantity_sold': 10,
        'total_revenue': 40000.00,
        'days_of_supply': 142.60000000000000000029,
        'is_slow_moving': true,
        'turnover_ratio': 0.21739130434782608696,
      });

      expect(model.name, 'Air Mineral 600ml');
      expect(model.currentStock, 46);
      expect(model.quantitySold, 10);
      expect(model.isSlowMoving, isTrue);
      expect(model.isDeadStock, isFalse);
      expect(model.turnoverRatio, closeTo(0.2174, 0.0001));
      expect(model.daysOfSupply, closeTo(142.6, 0.1));
      expect(model.tiedUpCapital, 115000.0);
    });

    test('keeps a null turnover ratio distinct from zero', () {
      // Null means "undefined" - no stock value to divide by - which the UI
      // must render differently from a genuine zero turnover.
      final model = ProductMovementModel.fromQueryResult(const {
        'id': 'p1',
        'name': 'Habis',
        'sku': 'SKU-1',
        'current_stock': 0,
        'cost_price': 5000.00,
        'stock_value': 0,
        'quantity_sold': 0,
        'total_revenue': 0,
        'total_cogs': 0,
        'total_profit': 0,
        'last_sold_at': null,
        'turnover_ratio': null,
        'days_of_supply': null,
        'is_slow_moving': false,
      });

      expect(model.turnoverRatio, isNull);
      expect(model.daysOfSupply, isNull);
      expect(model.isOutOfStock, isTrue);
      expect(model.isDeadStock, isFalse,
          reason: 'no stock means it cannot be dead stock');
      expect(model.tiedUpCapital, 0);
    });

    test('identifies dead stock: stocked but sold nothing', () {
      final model = ProductMovementModel.fromQueryResult(const {
        'id': 'p2',
        'name': 'Tidak Laku',
        'sku': 'SKU-2',
        'current_stock': 20,
        'cost_price': 10000.00,
        'stock_value': 200000.00,
        'quantity_sold': 0,
        'total_revenue': 0,
        'total_cogs': 0,
        'total_profit': 0,
        'last_sold_at': null,
        'turnover_ratio': 0,
        'days_of_supply': null,
        'is_slow_moving': true,
      });

      expect(model.isDeadStock, isTrue);
      expect(model.tiedUpCapital, 200000.0);
      expect(model.lastSoldAt, isNull);
    });

    test('accepts a boolean flag sent as a Postgres text value', () {
      final model = ProductMovementModel.fromQueryResult(const {
        'id': 'p3',
        'name': 'Teks Bool',
        'sku': 'SKU-3',
        'current_stock': 1,
        'cost_price': 1000.00,
        'stock_value': 1000.00,
        'quantity_sold': 0,
        'total_revenue': 0,
        'total_cogs': 0,
        'total_profit': 0,
        'last_sold_at': null,
        'turnover_ratio': null,
        'days_of_supply': null,
        'is_slow_moving': 't',
      });

      expect(model.isSlowMoving, isTrue);
    });

    test('computes average daily sales over a range', () {
      final model = ProductMovementModel.fromQueryResult(const {
        'id': 'p4',
        'name': 'Laris',
        'sku': 'SKU-4',
        'current_stock': 10,
        'cost_price': 1000.00,
        'stock_value': 10000.00,
        'quantity_sold': 60,
        'total_revenue': 120000.00,
        'total_cogs': 60000.00,
        'total_profit': 60000.00,
        'last_sold_at': null,
        'turnover_ratio': 6.0,
        'days_of_supply': 5.0,
        'is_slow_moving': false,
      });

      expect(model.averageDailySales(30), 2.0);
      expect(model.averageDailySales(0), 0, reason: 'must not divide by zero');
      expect(model.profitMargin, 50.0);
    });
  });
}
