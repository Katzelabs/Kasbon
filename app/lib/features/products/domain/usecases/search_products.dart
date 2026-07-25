import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Use case to search products by name
class SearchProducts implements UseCase<List<Product>, SearchProductsParams> {
  final ProductRepository _repository;

  SearchProducts(this._repository);

  @override
  Future<Either<Failure, List<Product>>> call(SearchProductsParams params) {
    return _repository.searchProducts(params.query);
  }
}

/// Parameters for SearchProducts use case
class SearchProductsParams extends Equatable {
  final String query;

  const SearchProductsParams({required this.query});

  @override
  List<Object?> get props => [query];
}
