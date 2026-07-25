import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product_profitability.dart';
import '../repositories/profit_report_repository.dart';

/// Use case to get top profitable products
class GetTopProfitableProducts
    extends UseCase<List<ProductProfitability>, int> {
  final ProfitReportRepository repository;

  GetTopProfitableProducts(this.repository);

  @override
  Future<Either<Failure, List<ProductProfitability>>> call(int limit) async {
    return await repository.getTopProfitableProducts(limit: limit);
  }
}
