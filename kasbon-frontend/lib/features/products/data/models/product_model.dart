import '../../domain/entities/product.dart';

/// Data Transfer Object for Product
/// Handles conversion between Supabase JSON and Product entity
class ProductModel {
  final String id;
  final String? categoryId;
  final String sku;
  final String name;
  final String? description;
  final String? barcode;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    this.categoryId,
    required this.sku,
    required this.name,
    this.description,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create ProductModel from Supabase JSON
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      sku: json['sku'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      barcode: json['barcode'] as String?,
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      stock: json['stock'] as int,
      minStock: json['min_stock'] as int? ?? 5,
      unit: json['unit'] as String? ?? 'pcs',
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert ProductModel to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'sku': sku,
      'name': name,
      'description': description,
      'barcode': barcode,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  /// Convert ProductModel to Product entity
  Product toEntity() {
    return Product(
      id: id,
      categoryId: categoryId,
      sku: sku,
      name: name,
      description: description,
      barcode: barcode,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      imageUrl: imageUrl,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create ProductModel from Product entity
  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      categoryId: product.categoryId,
      sku: product.sku,
      name: product.name,
      description: product.description,
      barcode: product.barcode,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      stock: product.stock,
      minStock: product.minStock,
      unit: product.unit,
      imageUrl: product.imageUrl,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }
}
