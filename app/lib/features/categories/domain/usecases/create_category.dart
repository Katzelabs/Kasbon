import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Parameters for CreateCategory use case
class CreateCategoryParams extends Equatable {
  final String name;

  const CreateCategoryParams({required this.name});

  @override
  List<Object?> get props => [name];
}

/// Use case to create a new category
class CreateCategory extends UseCase<Category, CreateCategoryParams> {
  final CategoryRepository repository;

  CreateCategory(this.repository);

  @override
  Future<Either<Failure, Category>> call(CreateCategoryParams params) {
    return repository.createCategory(params.name);
  }
}
