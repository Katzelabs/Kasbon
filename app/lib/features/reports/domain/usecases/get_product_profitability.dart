import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product_profitability.dart';
import '../repositories/profit_report_repository.dart';

/// Use case to get profitability for a specific product
class GetProductProfitability extends UseCase<ProductProfitability, String> {
  final ProfitReportRepository repository;

  GetProductProfitability(this.repository);

  @override
  Future<Either<Failure, ProductProfitability>> call(String productId) async {
    return await repository.getProductProfitability(productId: productId);
  }
}
