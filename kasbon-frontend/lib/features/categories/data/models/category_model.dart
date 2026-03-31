import '../../domain/entities/category.dart';

/// Data Transfer Object for Category
/// Handles conversion between Supabase JSON and Category entity
class CategoryModel {
  final String id;
  final String name;
  final String color;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create CategoryModel from Supabase JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#FF6B35',
      icon: json['icon'] as String? ?? 'category',
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert CategoryModel to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
    };
  }

  /// Convert CategoryModel to Category entity
  Category toEntity() {
    return Category(
      id: id,
      name: name,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create CategoryModel from Category entity
  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      color: category.color,
      icon: category.icon,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    );
  }
}
