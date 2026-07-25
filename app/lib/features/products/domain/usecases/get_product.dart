import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Use case to get a single product by ID
class GetProduct implements UseCase<Product, GetProductParams> {
  final ProductRepository _repository;

  GetProduct(this._repository);

  @override
  Future<Either<Failure, Product>> call(GetProductParams params) {
    return _repository.getProductById(params.id);
  }
}

/// Parameters for GetProduct use case
class GetProductParams extends Equatable {
  final String id;

  const GetProductParams({required this.id});

  @override
  List<Object?> get props => [id];
}
