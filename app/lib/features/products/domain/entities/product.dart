import 'package:equatable/equatable.dart';

/// Product entity representing a product in the POS system
class Product extends Equatable {
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

  const Product({
    required this.id,
    this.categoryId,
    required this.sku,
    required this.name,
    this.description,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    this.minStock = 5,
    this.unit = 'pcs',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Profit per unit (selling price - cost price)
  double get profit => sellingPrice - costPrice;

  /// Profit margin as percentage
  double get profitMargin =>
      costPrice > 0 ? ((sellingPrice - costPrice) / costPrice) * 100 : 0;

  /// Check if stock is low (at or below minimum stock but not zero)
  bool get isLowStock => stock > 0 && stock <= minStock;

  /// Check if product is out of stock
  bool get isOutOfStock => stock <= 0;

  /// Create a copy of the product with updated fields
  ///
  /// The nullable fields need a companion flag to be *cleared*, because `null`
  /// on its own means "leave alone" here. [clearImageUrl] was missing until a
  /// removed photo proved it: "Hapus Foto" deleted the object from storage and
  /// then saved `imageUrl: null`, which fell through to the existing URL. The
  /// row kept pointing at a file that was no longer there, and every render of
  /// that product showed the placeholder with no error to explain it.
  Product copyWith({
    String? id,
    String? categoryId,
    bool clearCategoryId = false,
    String? sku,
    String? name,
    String? description,
    String? barcode,
    double? costPrice,
    double? sellingPrice,
    int? stock,
    int? minStock,
    String? unit,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, sku];
}
