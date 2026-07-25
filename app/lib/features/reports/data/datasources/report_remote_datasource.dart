import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../../domain/repositories/report_repository.dart';
import '../models/daily_sales_model.dart';
import '../models/product_report_model.dart';
import '../models/sales_summary_model.dart';

/// Abstract interface for Report remote data source
abstract class ReportRemoteDataSource {
  Future<SalesSummaryModel> getSalesSummary({
    required DateTime from,
    required DateTime to,
  });
  Future<List<ProductReportModel>> getTopProducts({
    required DateTime from,
    required DateTime to,
    required ProductReportSortType sortBy,
    required int limit,
  });
  Future<List<DailySalesModel>> getDailySales({
    required DateTime from,
    required DateTime to,
  });
}

/// Implementation of ReportRemoteDataSource using Supabase RPC
class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final SupabaseClientProvider _provider;

  ReportRemoteDataSourceImpl(this._provider);

  @override
  Future<SalesSummaryModel> getSalesSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _provider.client.rpc('get_sales_summary', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
      });

      final data = result as Map<String, dynamic>;

      return SalesSummaryModel(
        totalRevenue: (data['total_revenue'] as num?)?.toDouble() ?? 0.0,
        totalProfit: (data['total_profit'] as num?)?.toDouble() ?? 0.0,
        transactionCount: (data['transaction_count'] as num?)?.toInt() ?? 0,
        itemsSold: (data['items_sold'] as num?)?.toInt() ?? 0,
        periodStart: from,
        periodEnd: to,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil ringkasan penjualan',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductReportModel>> getTopProducts({
    required DateTime from,
    required DateTime to,
    required ProductReportSortType sortBy,
    required int limit,
  }) async {
    try {
      final sortParam = switch (sortBy) {
        ProductReportSortType.quantity => 'quantity',
        ProductReportSortType.revenue => 'revenue',
        ProductReportSortType.profit => 'profit',
      };

      final result = await _provider.client.rpc('get_top_products', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_sort': sortParam,
        'p_limit': limit,
      });

      final data = result as List;
      return data
          .map((row) => ProductReportModel.fromQueryResult(
              Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil data produk terlaris',
        originalError: e,
      );
    }
  }

  @override
  Future<List<DailySalesModel>> getDailySales({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _provider.client.rpc('get_daily_sales', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
      });

      final data = result as List;
      return data
          .map((row) => DailySalesModel.fromQueryResult(
              Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil data penjualan harian',
        originalError: e,
      );
    }
  }
}
