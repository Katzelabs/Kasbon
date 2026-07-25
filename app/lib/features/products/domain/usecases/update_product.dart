import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Use case to update an existing product
class UpdateProduct implements UseCase<Product, Product> {
  final ProductRepository _repository;

  UpdateProduct(this._repository);

  @override
  Future<Either<Failure, Product>> call(Product params) {
    final updatedProduct = params.copyWith(
      updatedAt: DateTime.now(),
    );
    return _repository.updateProduct(updatedProduct);
  }
}
