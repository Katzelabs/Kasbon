import 'package:dartz/dartz.dart';

import '../../../../core/entities/paginated_result.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filter.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/product_model.dart';

/// Implementation of ProductRepository
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;

  ProductRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Product>>> getAllProducts() async {
    try {
      final models = await _remoteDataSource.getAllProducts();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> getProductById(String id) async {
    try {
      final model = await _remoteDataSource.getProductById(id);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      final models = await _remoteDataSource.searchProducts(query);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> createProduct(Product product) async {
    try {
      final model = ProductModel.fromEntity(product);
      final result = await _remoteDataSource.createProduct(model);
      return Right(result.toEntity());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    try {
      final model = ProductModel.fromEntity(product);
      final result = await _remoteDataSource.updateProduct(model);
      return Right(result.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteProduct(String id) async {
    try {
      await _remoteDataSource.deleteProduct(id);
      return const Right(unit);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getLowStockProducts() async {
    try {
      final models = await _remoteDataSource.getLowStockProducts();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
      String categoryId) async {
    try {
      final models = await _remoteDataSource.getProductsByCategory(categoryId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<Product>>> getProductsPaginated(
      ProductFilter filter) async {
    try {
      final totalCount = await _remoteDataSource.getProductsCount(
        searchQuery: filter.searchQuery,
        categoryId: filter.categoryId,
        stockFilter: filter.stockFilter,
      );

      final models = await _remoteDataSource.getProductsPaginated(
        searchQuery: filter.searchQuery,
        categoryId: filter.categoryId,
        stockFilter: filter.stockFilter,
        sortOption: filter.sortOption,
        limit: filter.pageSize,
        offset: filter.offset,
      );

      final products = models.map((m) => m.toEntity()).toList();

      return Right(PaginatedResult<Product>(
        items: products,
        totalCount: totalCount,
        currentPage: filter.page,
        pageSize: filter.pageSize,
      ));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    } catch (e) {
      return const Left(UnexpectedFailure());
    }
  }
}
