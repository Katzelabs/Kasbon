import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/daily_sales.dart';
import '../../domain/entities/product_report.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

/// Implementation of ReportRepository
class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource _remoteDataSource;

  ReportRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, SalesSummary>> getSalesSummary({
    required DateTime from,
    required DateTime to,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _remoteDataSource.getSalesSummary(
        from: from,
        to: to,
        filter: filter,
      );
      return Right(result.toEntity());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil ringkasan penjualan'));
    }
  }

  @override
  Future<Either<Failure, List<ProductReport>>> getTopProducts({
    required DateTime from,
    required DateTime to,
    required ProductReportSortType sortBy,
    required int limit,
    ReportFilter filter = ReportFilter.none,
  }) async {
    try {
      final result = await _remoteDataSource.getTopProducts(
        from: from,
        to: to,
        sortBy: sortBy,
        limit: limit,
        filter: filter,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil data produk terlaris'));
    }
  }

  @override
  Future<Either<Failure, List<DailySales>>> getDailySales({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _remoteDataSource.getDailySales(
        from: from,
        to: to,
      );
      return Right(result.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(
          DatabaseFailure(message: 'Gagal mengambil data penjualan harian'));
    }
  }
}
