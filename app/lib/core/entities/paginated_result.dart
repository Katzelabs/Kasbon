import 'package:equatable/equatable.dart';

/// Generic paginated result wrapper for any list type
///
/// Used for pagination across features (products, transactions, etc.)
class PaginatedResult<T> extends Equatable {
  final List<T> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  /// Total number of pages
  int get totalPages => totalCount == 0 ? 0 : (totalCount / pageSize).ceil();

  /// Whether there's a previous page
  bool get hasPreviousPage => currentPage > 1;

  /// Whether there's a next page
  bool get hasNextPage => currentPage < totalPages;

  /// Check if empty
  bool get isEmpty => items.isEmpty;

  /// Check if not empty
  bool get isNotEmpty => items.isNotEmpty;

  /// First item index (1-based for display)
  int get startIndex => isEmpty ? 0 : (currentPage - 1) * pageSize + 1;

  /// Last item index
  int get endIndex => isEmpty ? 0 : startIndex + items.length - 1;

  /// Display text like "1-8 dari 45 produk"
  String displayText(String itemLabel) =>
      '$startIndex-$endIndex dari $totalCount $itemLabel';

  @override
  List<Object?> get props => [items, totalCount, currentPage, pageSize];
}
