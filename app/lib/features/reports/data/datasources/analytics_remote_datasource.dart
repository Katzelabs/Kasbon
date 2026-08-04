import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/sales_trend_point.dart';
import '../models/category_slice_model.dart';
import '../models/customer_analytics_model.dart';
import '../models/heatmap_cell_model.dart';
import '../models/payment_slice_model.dart';
import '../models/product_movement_model.dart';
import '../models/sales_trend_point_model.dart';

/// Abstract interface for the advanced analytics remote data source.
abstract class AnalyticsRemoteDataSource {
  Future<List<SalesTrendPointModel>> getSalesTrend({
    required DateTime from,
    required DateTime to,
    required TrendGranularity granularity,
    ReportFilter filter = ReportFilter.none,
  });

  Future<List<CategorySliceModel>> getCategoryDistribution({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  });

  Future<List<PaymentSliceModel>> getPaymentDistribution({
    required DateTime from,
    required DateTime to,
  });

  Future<List<HeatmapCellModel>> getHourlyHeatmap({
    required DateTime from,
    required DateTime to,
  });

  Future<List<CustomerAnalyticsModel>> getTopCustomers({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  });

  Future<List<ProductMovementModel>> getProductMovement({
    required DateTime from,
    required DateTime to,
    int slowMovingDays = 90,
    int limit = 500,
  });
}

/// Implementation of [AnalyticsRemoteDataSource] backed by the report RPCs
/// added in `supabase/migrations/20260804010008_report_rpcs.sql`.
///
/// Every RPC takes its bucketing time zone as a parameter and defaults to
/// Asia/Jakarta server-side; the parameter is not sent from here, so all
/// bucketing follows the shop's business time zone rather than the device's.
/// Changing that is a deliberate decision, not something a traveling user's
/// device locale should do silently.
class AnalyticsRemoteDataSourceImpl implements AnalyticsRemoteDataSource {
  final SupabaseClientProvider _provider;

  AnalyticsRemoteDataSourceImpl(this._provider);

  /// Build the RPC params common to every filtered call.
  ///
  /// Null filter values are omitted entirely rather than sent as explicit
  /// nulls, letting the function defaults apply.
  ///
  /// Range bounds arrive as business wall-clock and are resolved to absolute
  /// instants by [BusinessTime.toRpcArgument]. Serialising them as-is would
  /// leave `toIso8601String` emitting no offset, so Postgres would read them in
  /// the server's zone and shift each boundary by the device's offset - quietly
  /// cutting the first hours off the period.
  Map<String, dynamic> _rangeParams(
    DateTime from,
    DateTime to, {
    ReportFilter filter = ReportFilter.none,
    bool includeCategory = true,
    bool includePayment = true,
  }) {
    return {
      'p_from': BusinessTime.toRpcArgument(from),
      'p_to': BusinessTime.toRpcArgument(to),
      if (includeCategory && filter.categoryId != null)
        'p_category_id': filter.categoryId,
      if (includePayment && filter.paymentMethod != null)
        'p_payment_method': filter.paymentMethod!.wireValue,
    };
  }

  /// Normalise a JSONB array result into typed rows.
  ///
  /// `jsonb_agg` yields `[]` for an empty set, so a non-list result means
  /// something unexpected came back and is treated as empty rather than
  /// crashing the report.
  List<Map<String, dynamic>> _rows(dynamic result) {
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<List<SalesTrendPointModel>> getSalesTrend({
    required DateTime from,
    required DateTime to,
    required TrendGranularity granularity,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_sales_trend',
        params: {
          ..._rangeParams(from, to, filter: filter),
          'p_granularity': granularity.wireValue,
        },
      );

      return _rows(result).map(SalesTrendPointModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil tren penjualan',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CategorySliceModel>> getCategoryDistribution({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_category_distribution',
        // The category filter is deliberately not forwarded: filtering the
        // category breakdown by category would leave a single slice.
        params: _rangeParams(from, to, filter: filter, includeCategory: false),
      );

      return _rows(result).map(CategorySliceModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil distribusi kategori',
        originalError: e,
      );
    }
  }

  @override
  Future<List<PaymentSliceModel>> getPaymentDistribution({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_payment_method_distribution',
        params: _rangeParams(from, to),
      );

      return _rows(result).map(PaymentSliceModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil distribusi metode pembayaran',
        originalError: e,
      );
    }
  }

  @override
  Future<List<HeatmapCellModel>> getHourlyHeatmap({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_hourly_heatmap',
        params: _rangeParams(from, to),
      );

      return _rows(result).map(HeatmapCellModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil pola penjualan per jam',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CustomerAnalyticsModel>> getTopCustomers({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_top_customers',
        params: {
          ..._rangeParams(from, to),
          'p_limit': limit,
        },
      );

      return _rows(result).map(CustomerAnalyticsModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil data pelanggan teratas',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductMovementModel>> getProductMovement({
    required DateTime from,
    required DateTime to,
    int slowMovingDays = 90,
    int limit = 500,
  }) async {
    try {
      final result = await _provider.client.rpc(
        'get_product_movement',
        params: {
          ..._rangeParams(from, to),
          'p_slow_days': slowMovingDays,
          'p_limit': limit,
        },
      );

      return _rows(result).map(ProductMovementModel.fromQueryResult).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil data pergerakan stok',
        originalError: e,
      );
    }
  }
}
