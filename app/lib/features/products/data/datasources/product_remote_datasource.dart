import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/query_limits.dart';
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
          .order('name')
          .limit(QueryLimits.productFetchCap);
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
          .order('name')
          .limit(QueryLimits.productFetchCap);
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
      // Filtered by the database rather than in Dart. This used to fetch every
      // active product and drop the ones above their minimum here, which meant
      // reading the whole catalogue to find the handful that were running out.
      //
      // `is_low_stock` is `stock <= COALESCE(min_stock, 5)`, which is the same
      // comparison this made in Dart - `ProductModel` reads a null `min_stock`
      // as 5 too, so nothing changes category. Scarcest first, as before.
      final result = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('is_low_stock', true)
          .order('stock')
          .limit(QueryLimits.productFetchCap);
      return result.map((json) => ProductModel.fromJson(json)).toList();
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
          .order('name')
          .limit(QueryLimits.productFetchCap);
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
      final query = _filteredQuery(
        searchQuery: searchQuery,
        categoryId: categoryId,
        stockFilter: stockFilter,
      );

      // Sort
      final (column, ascending) = _sortParams(sortOption);

      final result = await query
          .order(column, ascending: ascending)
          .range(offset, offset + limit - 1);

      return (result as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();
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
      final response = await _filteredQuery(
        searchQuery: searchQuery,
        categoryId: categoryId,
        stockFilter: stockFilter,
      ).count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw DatabaseException(
        message: 'Gagal menghitung jumlah produk',
        originalError: e,
      );
    }
  }

  /// The filter half of a product query - everything except sort and range.
  ///
  /// Shared by the page and its count on purpose. They used to build this
  /// separately and had drifted apart: the page applied the low-stock and
  /// available filters in Dart *after* `.range()` had already picked the rows,
  /// while the count skipped those two filters entirely and reported every
  /// active product. So "stok rendah" showed a handful of rows against a total
  /// counting the whole catalogue, and pages in the middle could come back
  /// empty. One builder is the only way those two stay in agreement.
  ///
  /// The stock comparisons are server-side now, via the `is_low_stock`
  /// generated column - see
  /// `supabase/migrations/20260804010002_core_schema.sql`.
  PostgrestFilterBuilder _filteredQuery({
    String? searchQuery,
    String? categoryId,
    required StockFilter stockFilter,
  }) {
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
      case StockFilter.lowStock:
        // `is_low_stock` alone also matches rows at zero, which belong to the
        // out-of-stock filter instead - "menipis" means running low, not gone.
        query = query.eq('is_low_stock', true).gt('stock', 0);
        break;
      case StockFilter.available:
        query = query.eq('is_low_stock', false);
        break;
      case StockFilter.all:
        break;
    }

    return query;
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
