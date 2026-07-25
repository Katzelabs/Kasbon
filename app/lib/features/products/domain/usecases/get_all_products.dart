import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Use case to get all active products
class GetAllProducts implements UseCaseNoParams<List<Product>> {
  final ProductRepository _repository;

  GetAllProducts(this._repository);

  @override
  Future<Either<Failure, List<Product>>> call() {
    return _repository.getAllProducts();
  }
}
