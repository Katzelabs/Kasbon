import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../../core/services/export/excel_exporter.dart';
import '../../../../core/services/export/export_result.dart';
import '../../../../core/services/export/pdf_exporter.dart';
import '../../../../core/constants/query_limits.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/product_filter.dart';
import '../../../products/domain/usecases/get_paginated_products.dart';
import '../../../receipt/domain/usecases/get_shop_settings.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/get_transactions.dart';
import '../../domain/entities/category_slice.dart';
import '../../domain/entities/product_report.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/sales_summary.dart';
import '../../domain/entities/sales_trend_point.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/get_category_distribution.dart';
import '../../domain/usecases/get_sales_summary.dart';
import '../../domain/usecases/get_sales_trend.dart';
import '../../domain/usecases/get_top_products.dart';
import 'date_range_provider.dart';
import 'report_filter_provider.dart';

/// What the user chose to export.
enum ExportFormat {
  /// Workbook with summary, transaction, line item and product sheets.
  excelWorkbook('Excel (.xlsx)', 'Ringkasan, transaksi, item & produk'),

  /// Printable sales report.
  pdfSalesReport('PDF - Laporan Penjualan', 'Ringkasan, tren & terlaris'),

  /// Printable product catalogue.
  pdfProductReport('PDF - Laporan Produk', 'Daftar produk, stok & nilai'),

  /// Every receipt in the period, archived in one document.
  pdfReceiptArchive('PDF - Arsip Struk', 'Semua struk pada periode ini');

  const ExportFormat(this.label, this.description);

  final String label;
  final String description;
}

/// Progress of the current export.
enum ExportStage { idle, fetching, generating, done, failed }

/// State of the export flow.
class ExportState {
  final ExportStage stage;
  final ExportResult? result;
  final String? errorMessage;

  const ExportState({
    this.stage = ExportStage.idle,
    this.result,
    this.errorMessage,
  });

  bool get isBusy =>
      stage == ExportStage.fetching || stage == ExportStage.generating;

  /// Message shown next to the spinner, so a slow export explains itself.
  String get progressLabel => switch (stage) {
        ExportStage.fetching => 'Mengambil data...',
        ExportStage.generating => 'Menyusun berkas...',
        _ => '',
      };
}

/// Fetches the data a report needs and turns it into a downloadable file.
///
/// Reads through the existing use cases rather than querying Supabase directly,
/// so an export always matches what the corresponding screen shows.
class ExportController extends StateNotifier<ExportState> {
  ExportController(this._ref) : super(const ExportState());

  final Ref _ref;

  /// Rows requested from the transaction history.
  ///
  /// Deliberately one above [ExcelExporter.maxTransactionRows] so the exporter
  /// can tell that truncation happened and report it, rather than silently
  /// returning exactly the cap.
  static const int _transactionFetchLimit =
      ExcelExporter.maxTransactionRows + 1;

  Future<ExportResult?> export(ExportFormat format) async {
    state = const ExportState(stage: ExportStage.fetching);

    try {
      final dateRange = _ref.read(dateRangeProvider);
      final filter = _ref.read(reportFilterProvider);
      final shopName = await _shopName();

      final result = switch (format) {
        ExportFormat.excelWorkbook => await _buildWorkbook(
            from: dateRange.from,
            to: dateRange.to,
            filter: filter,
            shopName: shopName,
          ),
        ExportFormat.pdfSalesReport => await _buildSalesPdf(
            from: dateRange.from,
            to: dateRange.to,
            filter: filter,
          ),
        ExportFormat.pdfProductReport => await _buildProductPdf(
            from: dateRange.from,
            to: dateRange.to,
          ),
        ExportFormat.pdfReceiptArchive => await _buildReceiptArchive(
            from: dateRange.from,
            to: dateRange.to,
          ),
      };

      state = ExportState(stage: ExportStage.done, result: result);
      return result;
    } catch (e) {
      state = ExportState(
        stage: ExportStage.failed,
        errorMessage: _friendlyError(e),
      );
      return null;
    }
  }

  void reset() => state = const ExportState();

  /// Shop settings are only decoration on the report header, so a failure to
  /// load them falls back to the app name rather than aborting the export.
  Future<String> _shopName() async {
    final result = await getIt<GetShopSettings>()();
    return result.fold((_) => 'KASBON', (settings) => settings.name);
  }

  Future<({String name, String? address, String? phone})> _shopHeader() async {
    final result = await getIt<GetShopSettings>()();
    return result.fold(
      (_) => (name: 'KASBON', address: null, phone: null),
      (settings) => (
        name: settings.name,
        address: settings.address,
        phone: settings.phone,
      ),
    );
  }

  Future<ExportResult> _buildWorkbook({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
    required String shopName,
  }) async {
    final transactions = await _fetchTransactions(from: from, to: to);
    final products = await _fetchProducts();
    final summary = await _fetchSummary(from: from, to: to, filter: filter);

    state = const ExportState(stage: ExportStage.generating);

    return ExcelExporter.buildWorkbook(
      transactions: transactions,
      products: products,
      summary: summary,
      from: from,
      to: to,
      shopName: shopName,
    );
  }

  Future<ExportResult> _buildSalesPdf({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
  }) async {
    final shop = await _shopHeader();
    final summary = await _fetchSummary(from: from, to: to, filter: filter);
    final trend = await _fetchTrend(from: from, to: to, filter: filter);
    final categories =
        await _fetchCategories(from: from, to: to, filter: filter);
    final topProducts =
        await _fetchTopProducts(from: from, to: to, filter: filter);

    state = const ExportState(stage: ExportStage.generating);

    return PdfExporter.buildSalesReport(
      summary: summary,
      trend: trend,
      categories: categories,
      topProducts: topProducts,
      from: from,
      to: to,
      shopName: shop.name,
      shopAddress: shop.address,
      shopPhone: shop.phone,
    );
  }

  Future<ExportResult> _buildProductPdf({
    required DateTime from,
    required DateTime to,
  }) async {
    final shop = await _shopHeader();
    final products = await _fetchProducts();

    state = const ExportState(stage: ExportStage.generating);

    return PdfExporter.buildProductReport(
      products: products,
      from: from,
      to: to,
      shopName: shop.name,
      shopAddress: shop.address,
      shopPhone: shop.phone,
    );
  }

  Future<ExportResult> _buildReceiptArchive({
    required DateTime from,
    required DateTime to,
  }) async {
    // Unlike the other exports, the receipt archive reproduces the customer's
    // receipt verbatim, so it needs the real shop settings rather than the
    // name-only fallback - a receipt without the shop's address is not the
    // receipt that was issued.
    final settingsResult = await getIt<GetShopSettings>()();
    final shopSettings = settingsResult.fold(
      (failure) => throw Exception(
        'Pengaturan toko belum diisi, struk tidak dapat dicetak',
      ),
      (settings) => settings,
    );

    final transactions = await _fetchTransactions(from: from, to: to);

    state = const ExportState(stage: ExportStage.generating);

    return PdfExporter.buildReceiptCompilation(
      transactions: transactions,
      shopSettings: shopSettings,
      from: from,
      to: to,
    );
  }

  // -------------------------------------------------------------------
  // Data fetching. Each unwraps Either and throws on failure so `export`
  // can report one error rather than every caller handling Left.
  // -------------------------------------------------------------------

  Future<List<Transaction>> _fetchTransactions({
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await getIt<GetTransactions>()(GetTransactionsParams(
      startDate: from,
      endDate: to,
      limit: _transactionFetchLimit,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (transactions) => transactions,
    );
  }

  /// The whole catalogue, walked a page at a time.
  ///
  /// A catalogue export means every product, which is exactly what
  /// [GetAllProducts] could not give: it issues one unbounded select, and
  /// PostgREST answers those by truncating at [QueryLimits.supabaseMaxRows]
  /// without a word. The workbook and the product PDF were both capped at a
  /// thousand rows and said they were complete.
  ///
  /// [GetPaginatedProducts] is the same use case the product list screen pages
  /// with, so an export sees the catalogue the app does.
  /// [QueryLimits.productExportCeiling] is a memory guard rather than a page
  /// size - a phone building a PDF holds every row at once.
  Future<List<Product>> _fetchProducts() async {
    final useCase = getIt<GetPaginatedProducts>();
    final products = <Product>[];

    for (var page = 1;; page++) {
      final result = await useCase(ProductFilter(
        page: page,
        pageSize: QueryLimits.chunkSize,
      ));

      final batch = result.fold(
        (failure) => throw Exception(failure.message),
        (paginated) => paginated,
      );

      products.addAll(batch.items);

      if (!batch.hasNextPage) break;
      if (products.length >= QueryLimits.productExportCeiling) break;
    }

    return products;
  }

  Future<SalesSummary> _fetchSummary({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
  }) async {
    final result = await getIt<GetSalesSummary>()(SalesSummaryParams(
      from: from,
      to: to,
      filter: filter,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (summary) => summary,
    );
  }

  Future<List<SalesTrendPoint>> _fetchTrend({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
  }) async {
    final result = await getIt<GetSalesTrend>()(SalesTrendParams.auto(
      from: from,
      to: to,
      filter: filter,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (points) => points,
    );
  }

  Future<List<CategorySlice>> _fetchCategories({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
  }) async {
    final result = await getIt<GetCategoryDistribution>()(AnalyticsRangeParams(
      from: from,
      to: to,
      filter: filter,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (slices) => slices,
    );
  }

  Future<List<ProductReport>> _fetchTopProducts({
    required DateTime from,
    required DateTime to,
    required ReportFilter filter,
  }) async {
    final result = await getIt<GetTopProducts>()(TopProductsParams(
      from: from,
      to: to,
      sortBy: ProductReportSortType.quantity,
      limit: 10,
      filter: filter,
    ));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (products) => products,
    );
  }

  /// Strip the `Exception: ` prefix Dart adds, which means nothing to a shop
  /// owner.
  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'Gagal membuat berkas ekspor';
  }
}

/// Provider for the export flow.
final exportControllerProvider =
    StateNotifierProvider.autoDispose<ExportController, ExportState>((ref) {
  return ExportController(ref);
});
