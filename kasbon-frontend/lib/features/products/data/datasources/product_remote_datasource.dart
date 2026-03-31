import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_client_provider.dart';
import '../../domain/entities/product_filter.dart';
import '../models/product_model.dart';

/// Abstract interface for Product remote data source
abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getAllProducts();
  Future<ProductModel> getProductById(String id);
  Future<List<ProductModel>> searchProducts(String query);
  Future<ProductModel> createProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String id);
  Future<List<ProductModel>> getLowStockProducts();
  Future<List<ProductModel>> getProductsByCategory(String categoryId);
  Future<List<ProductModel>> getProductsPaginated({
    String? searchQuery,
    String? categoryId,
    StockFilter stockFilter = StockFilter.all,
    ProductSortOption sortOption = ProductSortOption.nameAsc,
    required int limit,
    required int offset,
  });
  Future<int> getProductsCount({
    String? searchQuery,
    String? categoryId,
    StockFilter stockFilter = StockFilter.all,
  });
}

/// Implementation of ProductRemoteDataSource using Supabase
class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final SupabaseClientProvider _provider;

  ProductRemoteDataSourceImpl(this._provider);

  SupabaseClient get _client => _provider.client;
  String get _userId => _provider.requireUserId;

  @override
  Future<List<ProductModel>> getAllProducts() async {
    try {
      final result = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('name');
      return result.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil daftar produk',
        originalError: e,
      );
    }
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    try {
      final result = await _client
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (result == null) {
        throw const NotFoundException(message: 'Produk tidak ditemukan');
      }
      return ProductModel.fromJson(result);
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil produk',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final result = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .ilike('name', '%$query%')
          .order('name');
      return result.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mencari produk',
        originalError: e,
      );
    }
  }

  @override
  Future<ProductModel> createProduct(ProductModel product) async {
    try {
      final json = product.toJson();
      json['user_id'] = _userId;
      json.remove('id'); // Let Supabase generate UUID
      final result = await _client
          .from('products')
          .insert(json)
          .select()
          .single();
      return ProductModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal menambahkan produk',
        originalError: e,
      );
    }
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    try {
      final json = product.toJson();
      json.remove('user_id');
      json.remove('created_at');
      final result = await _client
          .from('products')
          .update(json)
          .eq('id', product.id)
          .select()
          .single();
      return ProductModel.fromJson(result);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const NotFoundException(message: 'Produk tidak ditemukan');
      }
      throw DatabaseException(
        message: 'Gagal mengupdate produk',
        originalError: e,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengupdate produk',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      await _client
          .from('products')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal menghapus produk',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      // Use RPC or raw filter - Supabase doesn't support column-to-column comparison directly
      // So we fetch active products and filter in Dart
      final result = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('stock');
      return result
          .map((json) => ProductModel.fromJson(json))
          .where((p) => p.stock <= p.minStock)
          .toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil produk stok rendah',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    try {
      final result = await _client
          .from('products')
          .select()
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('name');
      return result.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil produk berdasarkan kategori',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductModel>> getProductsPaginated({
    String? searchQuery,
    String? categoryId,
    StockFilter stockFilter = StockFilter.all,
    ProductSortOption sortOption = ProductSortOption.nameAsc,
    required int limit,
    required int offset,
  }) async {
    try {
      PostgrestFilterBuilder query =
          _client.from('products').select().eq('is_active', true);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      // Stock filter
      switch (stockFilter) {
        case StockFilter.outOfStock:
          query = query.lte('stock', 0);
          break;
        case StockFilter.available:
        case StockFilter.lowStock:
        case StockFilter.all:
          // handled post-query for column comparisons
          break;
      }

      // Sort
      final (column, ascending) = _sortParams(sortOption);

      final result = await query
          .order(column, ascending: ascending)
          .range(offset, offset + limit - 1);

      var products =
          (result as List).map((json) => ProductModel.fromJson(json)).toList();

      // Post-filter for stock filters that need column comparison
      if (stockFilter == StockFilter.lowStock) {
        products =
            products.where((p) => p.stock > 0 && p.stock <= p.minStock).toList();
      } else if (stockFilter == StockFilter.available) {
        products = products.where((p) => p.stock > p.minStock).toList();
      }

      return products;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal mengambil daftar produk',
        originalError: e,
      );
    }
  }

  @override
  Future<int> getProductsCount({
    String? searchQuery,
    String? categoryId,
    StockFilter stockFilter = StockFilter.all,
  }) async {
    try {
      PostgrestFilterBuilder query =
          _client.from('products').select().eq('is_active', true);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      switch (stockFilter) {
        case StockFilter.outOfStock:
          query = query.lte('stock', 0);
          break;
        case StockFilter.available:
        case StockFilter.lowStock:
        case StockFilter.all:
          break;
      }

      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal menghitung jumlah produk',
        originalError: e,
      );
    }
  }

  (String, bool) _sortParams(ProductSortOption option) {
    switch (option) {
      case ProductSortOption.nameAsc:
        return ('name', true);
      case ProductSortOption.nameDesc:
        return ('name', false);
      case ProductSortOption.priceAsc:
        return ('selling_price', true);
      case ProductSortOption.priceDesc:
        return ('selling_price', false);
      case ProductSortOption.stockAsc:
        return ('stock', true);
      case ProductSortOption.stockDesc:
        return ('stock', false);
    }
  }
}
