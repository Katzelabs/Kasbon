import 'package:equatable/equatable.dart';

/// Default page size for product pagination
const int kProductsPageSize = 10;

/// Sort options for product list
enum ProductSortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  stockAsc,
  stockDesc;

  /// Display label for the sort option
  String get label {
    switch (this) {
      case ProductSortOption.nameAsc:
        return 'Nama A-Z';
      case ProductSortOption.nameDesc:
        return 'Nama Z-A';
      case ProductSortOption.priceAsc:
        return 'Harga Terendah';
      case ProductSortOption.priceDesc:
        return 'Harga Tertinggi';
      case ProductSortOption.stockAsc:
        return 'Stok Terendah';
      case ProductSortOption.stockDesc:
        return 'Stok Tertinggi';
    }
  }

  /// Short label for mobile display
  String get shortLabel {
    switch (this) {
      case ProductSortOption.nameAsc:
        return 'A-Z';
      case ProductSortOption.nameDesc:
        return 'Z-A';
      case ProductSortOption.priceAsc:
        return 'Harga ↑';
      case ProductSortOption.priceDesc:
        return 'Harga ↓';
      case ProductSortOption.stockAsc:
        return 'Stok ↑';
      case ProductSortOption.stockDesc:
        return 'Stok ↓';
    }
  }
}

/// Stock status filter options
enum StockFilter {
  all,
  available,
  lowStock,
  outOfStock;

  /// Display label for the stock filter
  String get label {
    switch (this) {
      case StockFilter.all:
        return 'Semua';
      case StockFilter.available:
        return 'Tersedia';
      case StockFilter.lowStock:
        return 'Stok Rendah';
      case StockFilter.outOfStock:
        return 'Habis';
    }
  }
}

/// Encapsulates all filter criteria + pagination for product queries
class ProductFilter extends Equatable {
  final String? searchQuery;
  final String? categoryId;
  final StockFilter stockFilter;
  final ProductSortOption sortOption;
  final int page;
  final int pageSize;

  const ProductFilter({
    this.searchQuery,
    this.categoryId,
    this.stockFilter = StockFilter.all,
    this.sortOption = ProductSortOption.nameAsc,
    this.page = 1,
    this.pageSize = kProductsPageSize,
  });

  /// Calculate SQL offset from page number
  int get offset => (page - 1) * pageSize;

  /// Check if any filter is active
  bool get hasActiveFilters =>
      searchQuery != null && searchQuery!.isNotEmpty ||
      categoryId != null ||
      stockFilter != StockFilter.all;

  /// Create copy with updated values
  ProductFilter copyWith({
    String? searchQuery,
    String? categoryId,
    StockFilter? stockFilter,
    ProductSortOption? sortOption,
    int? page,
    int? pageSize,
    bool clearSearchQuery = false,
    bool clearCategoryId = false,
  }) {
    return ProductFilter(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      stockFilter: stockFilter ?? this.stockFilter,
      sortOption: sortOption ?? this.sortOption,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  /// Reset to first page (when filters change)
  ProductFilter resetToFirstPage() => copyWith(page: 1);

  @override
  List<Object?> get props => [
        searchQuery,
        categoryId,
        stockFilter,
        sortOption,
        page,
        pageSize,
      ];
}
