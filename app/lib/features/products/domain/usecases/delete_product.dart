import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/image_storage/image_storage_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/product_repository.dart';

/// Use case to soft delete a product (set is_active = false)
class DeleteProduct implements UseCase<Unit, DeleteProductParams> {
  final ProductRepository _repository;
  final ImageStorageService _imageStorageService;

  DeleteProduct(this._repository, this._imageStorageService);

  @override
  Future<Either<Failure, Unit>> call(DeleteProductParams params) async {
    // First, get the product to check for image
    final productResult = await _repository.getProductById(params.id);

    return productResult.fold(
      (failure) => Left(failure),
      (product) async {
        // Delete the image file if it exists
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          try {
            await _imageStorageService.deleteImage(product.imageUrl!);
          } catch (_) {
            // Ignore image deletion errors, continue with product deletion
          }
        }

        // Then soft delete the product
        return _repository.deleteProduct(params.id);
      },
    );
  }
}

/// Parameters for DeleteProduct use case
class DeleteProductParams extends Equatable {
  final String id;

  const DeleteProductParams({required this.id});

  @override
  List<Object?> get props => [id];
}
