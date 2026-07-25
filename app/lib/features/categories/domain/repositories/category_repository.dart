import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/category.dart';

/// Abstract repository interface for Category operations
abstract class CategoryRepository {
  /// Get all categories ordered by sort_order
  Future<Either<Failure, List<Category>>> getAllCategories();

  /// Get a single category by ID
  Future<Either<Failure, Category>> getCategoryById(String id);

  /// Create a new category with the given name
  Future<Either<Failure, Category>> createCategory(String name);
}
