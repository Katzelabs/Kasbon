import 'package:dartz/dartz.dart';

import '../errors/failures.dart';

/// Type alias for Future that returns Either<Failure, T>
///
/// Use this for repository methods that return data:
/// ```dart
/// ResultFuture<List<Product>> getProducts();
/// ResultFuture<Product> getProductById(String id);
/// ```
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Type alias for Future that returns Either<Failure, void>
///
/// Use this for repository methods that don't return data:
/// ```dart
/// ResultVoid deleteProduct(String id);
/// ResultVoid updateProduct(Product product);
/// ```
typedef ResultVoid = Future<Either<Failure, void>>;

/// Type alias for Map with String keys and dynamic values
///
/// Use this for JSON data:
/// ```dart
/// Product.fromJson(DataMap json);
/// DataMap toJson();
/// ```
typedef DataMap = Map<String, dynamic>;
