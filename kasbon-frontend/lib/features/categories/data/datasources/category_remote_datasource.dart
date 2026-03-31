import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../models/category_model.dart';

/// Abstract interface for Category remote data source
abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getAllCategories();
  Future<CategoryModel> getCategoryById(String id);
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
          .order('sort_order');
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
}
