import 'package:dartz/dartz.dart';

import '../../../../core/entities/paginated_result.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../entities/product_filter.dart';
import '../repositories/product_repository.dart';

/// Use case to get paginated products with filtering
class GetPaginatedProducts
    implements UseCase<PaginatedResult<Product>, ProductFilter> {
  final ProductRepository _repository;

  GetPaginatedProducts(this._repository);

  @override
  Future<Either<Failure, PaginatedResult<Product>>> call(ProductFilter filter) {
    return _repository.getProductsPaginated(filter);
  }
}
