import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Use case to get all categories
class GetAllCategories extends UseCaseNoParams<List<Category>> {
  final CategoryRepository repository;

  GetAllCategories(this.repository);

  @override
  Future<Either<Failure, List<Category>>> call() async {
    return await repository.getAllCategories();
  }
}
