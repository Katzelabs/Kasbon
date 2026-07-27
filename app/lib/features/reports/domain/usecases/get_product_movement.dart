import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product_movement.dart';
import '../repositories/analytics_repository.dart';

/// Use case to get inventory movement for every active product.
///
/// Backs both the turnover report and the slow-moving report - see
/// [ProductMovementX] for the two derived views.
class GetProductMovement
    extends UseCase<List<ProductMovement>, ProductMovementParams> {
  final AnalyticsRepository repository;

  GetProductMovement(this.repository);

  @override
  Future<Either<Failure, List<ProductMovement>>> call(
      ProductMovementParams params) async {
    return await repository.getProductMovement(
      from: params.from,
      to: params.to,
      slowMovingDays: params.slowMovingDays,
      limit: params.limit,
    );
  }
}

/// Parameters for the product movement query.
class ProductMovementParams extends Equatable {
  final DateTime from;
  final DateTime to;

  /// Days-of-supply threshold above which a stocked product counts as
  /// slow-moving. Roughly a quarter's worth of stock by default.
  final int slowMovingDays;

  /// Cap on the number of products returned. A UMKM catalogue is well under
  /// this, but the bound keeps a pathological catalogue from stalling the app.
  final int limit;

  const ProductMovementParams({
    required this.from,
    required this.to,
    this.slowMovingDays = 90,
    this.limit = 500,
  });

  @override
  List<Object?> get props => [from, to, slowMovingDays, limit];
}
