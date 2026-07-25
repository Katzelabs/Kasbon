import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/sku_generator.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Use case to create a new product
class CreateProduct implements UseCase<Product, CreateProductParams> {
  final ProductRepository _repository;

  CreateProduct(this._repository);

  @override
  Future<Either<Failure, Product>> call(CreateProductParams params) {
    final now = DateTime.now();
    final product = Product(
      id: const Uuid().v4(),
      categoryId: params.categoryId,
      sku: SkuGenerator.generate(params.name),
      name: params.name,
      description: params.description,
      barcode: params.barcode,
      costPrice: params.costPrice,
      sellingPrice: params.sellingPrice,
      stock: params.stock,
      minStock: params.minStock,
      unit: params.unit,
      imageUrl: params.imageUrl,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    return _repository.createProduct(product);
  }
}

/// Parameters for CreateProduct use case
class CreateProductParams extends Equatable {
  final String name;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String unit;
  final String? categoryId;
  final String? description;
  final String? barcode;
  final String? imageUrl;

  const CreateProductParams({
    required this.name,
    required this.costPrice,
    required this.sellingPrice,
    this.stock = 0,
    this.minStock = 5,
    this.unit = 'pcs',
    this.categoryId,
    this.description,
    this.barcode,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [
        name,
        costPrice,
        sellingPrice,
        stock,
        minStock,
        unit,
        categoryId,
        description,
        barcode,
        imageUrl,
      ];
}
