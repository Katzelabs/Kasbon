import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/dashboard_summary_model.dart';

/// Abstract interface for Dashboard remote data source
abstract class DashboardRemoteDataSource {
  Future<DashboardSummaryModel> getDashboardSummary();
  Future<double> getTodaySales();
  Future<int> getTodayTransactionCount();
  Future<double> getTodayProfit();
  Future<double> getYesterdaySales();
  Future<double> getYesterdayProfit();
  Future<int> getLowStockProductCount();
}

/// Implementation of DashboardRemoteDataSource using Supabase RPC
class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final SupabaseClientProvider _provider;

  DashboardRemoteDataSourceImpl(this._provider);

  @override
  Future<DashboardSummaryModel> getDashboardSummary() async {
    try {
      final result = await _provider.client.rpc('get_dashboard_summary');
      final data = result as Map<String, dynamic>;

      return DashboardSummaryModel.fromQueryResults(
        todaySales: (data['today_sales'] as num?)?.toDouble() ?? 0.0,
        todayProfit: (data['today_profit'] as num?)?.toDouble() ?? 0.0,
        transactionCount: (data['transaction_count'] as num?)?.toInt() ?? 0,
        yesterdaySales: (data['yesterday_sales'] as num?)?.toDouble() ?? 0.0,
        yesterdayProfit: (data['yesterday_profit'] as num?)?.toDouble() ?? 0.0,
        lowStockCount: (data['low_stock_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal memuat ringkasan dashboard',
        originalError: e,
      );
    }
  }

  @override
  Future<double> getTodaySales() async {
    final summary = await getDashboardSummary();
    return summary.todaySales;
  }

  @override
  Future<int> getTodayTransactionCount() async {
    final summary = await getDashboardSummary();
    return summary.transactionCount;
  }

  @override
  Future<double> getTodayProfit() async {
    final summary = await getDashboardSummary();
    return summary.todayProfit;
  }

  @override
  Future<double> getYesterdaySales() async {
    final summary = await getDashboardSummary();
    return summary.yesterdaySales;
  }

  @override
  Future<double> getYesterdayProfit() async {
    final summary = await getDashboardSummary();
    return summary.yesterdayProfit;
  }

  @override
  Future<int> getLowStockProductCount() async {
    final summary = await getDashboardSummary();
    return summary.lowStockCount;
  }
}
