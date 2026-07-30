import 'package:uuid/uuid.dart';

import '../../../../core/constants/query_limits.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/category_model.dart';

/// Abstract interface for Category remote data source
abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getAllCategories();
  Future<CategoryModel> getCategoryById(String id);
  Future<CategoryModel> createCategory(String name);
}

/// Implementation of CategoryRemoteDataSource using Supabase
class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final SupabaseClientProvider _provider;

  CategoryRemoteDataSourceImpl(this._provider);

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final result = await _provider.client
          .from('categories')
          .select()
          .order('sort_order')
          .limit(QueryLimits.categoryFetchCap);
      return result.map((json) => CategoryModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil daftar kategori',
        originalError: e,
      );
    }
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    try {
      final result = await _provider.client
          .from('categories')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (result == null) {
        throw const NotFoundException(message: 'Kategori tidak ditemukan');
      }
      return CategoryModel.fromJson(result);
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil kategori',
        originalError: e,
      );
    }
  }

  @override
  Future<CategoryModel> createCategory(String name) async {
    try {
      final userId = _provider.requireUserId;

      // Find-or-create: check if category with same name already exists
      final existing = await _provider.client
          .from('categories')
          .select()
          .eq('user_id', userId)
          .eq('name', name)
          .maybeSingle();

      if (existing != null) {
        return CategoryModel.fromJson(existing);
      }

      final id = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final data = {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': '#FF6B35',
        'icon': 'category',
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      };
      final result = await _provider.client
          .from('categories')
          .insert(data)
          .select()
          .single();
      return CategoryModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal membuat kategori',
        originalError: e,
      );
    }
  }
}
