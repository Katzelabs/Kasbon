import 'package:dartz/dartz.dart';

import '../../../../core/entities/paginated_result.dart';
import '../../../../core/errors/failures.dart';
import '../entities/product.dart';
import '../entities/product_filter.dart';

/// Abstract repository interface for Product operations
abstract class ProductRepository {
  /// Get all active products
  Future<Either<Failure, List<Product>>> getAllProducts();

  /// Get a single product by ID
  Future<Either<Failure, Product>> getProductById(String id);

  /// Search products by name
  Future<Either<Failure, List<Product>>> searchProducts(String query);

  /// Create a new product
  Future<Either<Failure, Product>> createProduct(Product product);

  /// Update an existing product
  Future<Either<Failure, Product>> updateProduct(Product product);

  /// Soft delete a product (set is_active = false)
  Future<Either<Failure, Unit>> deleteProduct(String id);

  /// Get all products with low stock (stock <= minStock)
  Future<Either<Failure, List<Product>>> getLowStockProducts();

  /// Get products by category ID
  Future<Either<Failure, List<Product>>> getProductsByCategory(
      String categoryId);

  /// Get paginated products with SQL-level filtering
  Future<Either<Failure, PaginatedResult<Product>>> getProductsPaginated(
      ProductFilter filter);
}
