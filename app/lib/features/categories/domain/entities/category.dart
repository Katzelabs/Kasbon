import 'package:equatable/equatable.dart';

/// Category entity representing a product category in the POS system
class Category extends Equatable {
  final String id;
  final String name;
  final String color;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.color = '#FF6B35',
    this.icon = 'category',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of the category with updated fields
  Category copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id];
}
