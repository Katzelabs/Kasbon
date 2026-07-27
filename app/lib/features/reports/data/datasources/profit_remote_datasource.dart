import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/product_profitability_model.dart';
import '../models/profit_summary_model.dart';

/// Abstract interface for Profit Report remote data source
abstract class ProfitRemoteDataSource {
  Future<ProfitSummaryModel> getProfitByDateRange({
    required DateTime from,
    required DateTime to,
  });
  Future<List<ProductProfitabilityModel>> getTopProfitableProducts({
    required int limit,
  });
  Future<ProductProfitabilityModel> getProductProfitability({
    required String productId,
  });
}

/// Implementation of ProfitRemoteDataSource using Supabase RPC
class ProfitRemoteDataSourceImpl implements ProfitRemoteDataSource {
  final SupabaseClientProvider _provider;

  ProfitRemoteDataSourceImpl(this._provider);

  @override
  Future<ProfitSummaryModel> getProfitByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _provider.client.rpc('get_profit_summary', params: {
        'p_from': BusinessTime.toRpcArgument(from),
        'p_to': BusinessTime.toRpcArgument(to),
      });

      final data = result as Map<String, dynamic>;
      final totalSales = (data['total_sales'] as num?)?.toDouble() ?? 0.0;
      final totalProfit = (data['total_profit'] as num?)?.toDouble() ?? 0.0;
      final transactionCount =
          (data['transaction_count'] as num?)?.toInt() ?? 0;
      final profitMargin =
          totalSales > 0 ? (totalProfit / totalSales) * 100 : 0.0;

      return ProfitSummaryModel(
        totalProfit: totalProfit,
        totalSales: totalSales,
        profitMargin: profitMargin,
        transactionCount: transactionCount,
        periodStart: from,
        periodEnd: to,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil ringkasan laba',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductProfitabilityModel>> getTopProfitableProducts({
    required int limit,
  }) async {
    try {
      final result =
          await _provider.client.rpc('get_top_profitable_products', params: {
        'p_limit': limit,
      });

      final data = result as List;
      return data
          .map((row) => ProductProfitabilityModel.fromQueryResult(
              Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil produk terlaris',
        originalError: e,
      );
    }
  }

  @override
  Future<ProductProfitabilityModel> getProductProfitability({
    required String productId,
  }) async {
    try {
      final result =
          await _provider.client.rpc('get_product_profitability', params: {
        'p_product_id': productId,
      });

      final data = result as Map<String, dynamic>;
      if (data.isEmpty) {
        return ProductProfitabilityModel(
          productId: productId,
          productName: '',
          totalProfit: 0,
          totalSold: 0,
          averageMargin: 0,
        );
      }

      return ProductProfitabilityModel.fromQueryResult(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil data keuntungan produk',
        originalError: e,
      );
    }
  }
}
