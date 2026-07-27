import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/category_slice.dart';
import '../../domain/entities/customer_analytics.dart';
import '../../domain/entities/heatmap_cell.dart';
import '../../domain/entities/payment_slice.dart';
import '../../domain/entities/product_movement.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/sales_trend_point.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../datasources/analytics_remote_datasource.dart';

/// Implementation of [AnalyticsRepository].
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource _remoteDataSource;

  AnalyticsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<SalesTrendPoint>>> getSalesTrend({
    required DateTime from,
    required DateTime to,
    required TrendGranularity granularity,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _remoteDataSource.getSalesTrend(
        from: from,
        to: to,
        granularity: granularity,
        filter: filter,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil tren penjualan'));
    }
  }

  @override
  Future<Either<Failure, List<CategorySlice>>> getCategoryDistribution({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _remoteDataSource.getCategoryDistribution(
        from: from,
        to: to,
        filter: filter,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil distribusi kategori'));
    }
  }

  @override
  Future<Either<Failure, List<PaymentSlice>>> getPaymentDistribution({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _remoteDataSource.getPaymentDistribution(
        from: from,
        to: to,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(DatabaseFailure(
          message: 'Gagal mengambil distribusi metode pembayaran'));
    }
  }

  @override
  Future<Either<Failure, HourlyHeatmap>> getHourlyHeatmap({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _remoteDataSource.getHourlyHeatmap(
        from: from,
        to: to,
      );
      // Wrapping here rather than in the data source keeps the grid-filling and
      // peak-hour logic in the domain layer, where the UI reads it from.
      return Right(HourlyHeatmap(result.map((m) => m.toEntity()).toList()));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil pola penjualan per jam'));
    }
  }

  @override
  Future<Either<Failure, List<CustomerAnalytics>>> getTopCustomers({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    try {
      final result = await _remoteDataSource.getTopCustomers(
        from: from,
        to: to,
        limit: limit,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil data pelanggan teratas'));
    }
  }

  @override
  Future<Either<Failure, List<ProductMovement>>> getProductMovement({
    required DateTime from,
    required DateTime to,
    int slowMovingDays = 90,
    int limit = 500,
  }) async {
    try {
      final result = await _remoteDataSource.getProductMovement(
        from: from,
        to: to,
        slowMovingDays: slowMovingDays,
        limit: limit,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil data pergerakan stok'));
    }
  }
}
