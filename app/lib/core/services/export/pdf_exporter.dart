import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/products/domain/entities/product.dart';
import '../../../features/reports/domain/entities/category_slice.dart';
import '../../../features/reports/domain/entities/product_report.dart';
import '../../../features/reports/domain/entities/sales_summary.dart';
import '../../../features/reports/domain/entities/sales_trend_point.dart';
import '../../../features/receipt/domain/entities/shop_settings.dart';
import '../../../features/transactions/domain/entities/transaction.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/receipt_generator.dart';
import 'excel_exporter.dart';
import 'export_result.dart';

/// Builds printable PDF reports.
///
/// Uses the built-in Helvetica family rather than bundling a font, which keeps
/// roughly half a megabyte out of the app. The trade-off is that the standard
/// PDF fonts are WinAnsi-encoded, not Unicode: every string these reports emit
/// is therefore kept to ASCII, including the separators. Shop names and product
/// names come from user data and could contain anything, but those degrade to a
/// substituted glyph rather than failing the export.
class PdfExporter {
  PdfExporter._();

  /// Cap on table rows per report, to keep a huge history from producing an
  /// unusable document. Overflow is reported via [ExportResult.omittedRowCount].
  static const int maxTableRows = 1000;

  /// Cap on receipts in a compilation. Lower than [maxTableRows] because each
  /// receipt is a whole block rather than a single row.
  static const int maxReceipts = 300;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy', 'id_ID');
  static final DateFormat _dateTimeFormat =
      DateFormat('d MMM yyyy HH:mm', 'id_ID');

  static const PdfColor _primary = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _headerBg = PdfColor.fromInt(0xFFEFF2F6);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);

  /// Sales report: summary figures, the day-by-day trend, category split and
  /// best sellers.
  static Future<ExportResult> buildSalesReport({
    required SalesSummary summary,
    required List<SalesTrendPoint> trend,
    required List<CategorySlice> categories,
    required List<ProductReport> topProducts,
    required DateTime from,
    required DateTime to,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final doc = pw.Document();
    final omitted =
        trend.length > maxTableRows ? trend.length - maxTableRows : 0;
    final visibleTrend = omitted > 0 ? trend.sublist(0, maxTableRows) : trend;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // Default is 20, which a full-length table overruns. Still low enough
        // to catch a genuinely runaway layout.
        maxPages: 250,
        header: (context) => _header(
          context: context,
          shopName: shopName,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          title: 'Laporan Penjualan',
          from: from,
          to: to,
        ),
        footer: _footer,
        build: (context) => [
          _summaryGrid(summary),
          pw.SizedBox(height: 20),
          if (visibleTrend.isNotEmpty) ...[
            _sectionTitle('Rincian Penjualan'),
            pw.SizedBox(height: 8),
            _trendTable(visibleTrend),
            if (omitted > 0) ...[
              pw.SizedBox(height: 6),
              _note('$omitted baris tidak dimuat karena melebihi batas '
                  '$maxTableRows baris.'),
            ],
            pw.SizedBox(height: 20),
          ],
          if (categories.isNotEmpty) ...[
            _sectionTitle('Penjualan per Kategori'),
            pw.SizedBox(height: 8),
            _categoryTable(categories),
            pw.SizedBox(height: 20),
          ],
          if (topProducts.isNotEmpty) ...[
            _sectionTitle('Produk Terlaris'),
            pw.SizedBox(height: 8),
            _topProductsTable(topProducts),
          ],
        ],
      ),
    );

    return ExportResult(
      bytes: await doc.save(),
      fileName: ExcelExporter.buildFileName(
        from: from,
        to: to,
        extension: 'pdf',
        prefix: 'kasbon_penjualan',
      ),
      mimeType: ExportResult.pdfMimeType,
      omittedRowCount: omitted,
    );
  }

  /// Product report: the catalogue with cost, price, margin and stock value.
  static Future<ExportResult> buildProductReport({
    required List<Product> products,
    required DateTime from,
    required DateTime to,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final doc = pw.Document();
    final omitted =
        products.length > maxTableRows ? products.length - maxTableRows : 0;
    final visible = omitted > 0 ? products.sublist(0, maxTableRows) : products;

    final totalStockValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.stock * p.costPrice),
    );
    final lowStockCount = products.where((p) => p.stock <= p.minStock).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // Default is 20, which a full-length table overruns. Still low enough
        // to catch a genuinely runaway layout.
        maxPages: 250,
        header: (context) => _header(
          context: context,
          shopName: shopName,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          title: 'Laporan Produk',
          from: from,
          to: to,
        ),
        footer: _footer,
        build: (context) => [
          pw.Row(
            children: [
              _statBox('Jumlah Produk', '${products.length}'),
              pw.SizedBox(width: 10),
              _statBox(
                'Nilai Stok',
                CurrencyFormatter.format(totalStockValue),
              ),
              pw.SizedBox(width: 10),
              _statBox('Stok Menipis', '$lowStockCount'),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Daftar Produk'),
          pw.SizedBox(height: 8),
          _productTable(visible),
          if (omitted > 0) ...[
            pw.SizedBox(height: 6),
            _note('$omitted produk tidak dimuat karena melebihi batas '
                '$maxTableRows baris.'),
          ],
        ],
      ),
    );

    return ExportResult(
      bytes: await doc.save(),
      fileName: ExcelExporter.buildFileName(
        from: from,
        to: to,
        extension: 'pdf',
        prefix: 'kasbon_produk',
      ),
      mimeType: ExportResult.pdfMimeType,
      omittedRowCount: omitted,
    );
  }

  /// Receipt compilation: every receipt in the period, one block each.
  ///
  /// Reuses [ReceiptGenerator], the same 42-column text used for thermal
  /// printing and sharing, so an archived receipt is byte-for-byte what the
  /// customer got. Rendered in Courier because that alignment only holds in a
  /// monospace face.
  static Future<ExportResult> buildReceiptCompilation({
    required List<Transaction> transactions,
    required ShopSettings shopSettings,
    required DateTime from,
    required DateTime to,
  }) async {
    final doc = pw.Document();
    final omitted = transactions.length > maxReceipts
        ? transactions.length - maxReceipts
        : 0;
    final visible =
        omitted > 0 ? transactions.sublist(0, maxReceipts) : transactions;

    final mono = pw.Font.courier();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 250,
        header: (context) => _header(
          context: context,
          shopName: shopSettings.name,
          shopAddress: shopSettings.address,
          shopPhone: shopSettings.phone,
          title: 'Arsip Struk',
          from: from,
          to: to,
        ),
        footer: _footer,
        build: (context) {
          if (visible.isEmpty) {
            return [
              pw.Text(
                'Tidak ada transaksi pada periode ini.',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            ];
          }

          return [
            for (final transaction in visible)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _muted, width: 0.5),
                ),
                child: pw.Text(
                  ReceiptGenerator.generate(
                    transaction: transaction,
                    shopSettings: shopSettings,
                  ),
                  style: pw.TextStyle(font: mono, fontSize: 7.5),
                ),
              ),
            if (omitted > 0)
              _note('$omitted struk tidak dimuat karena melebihi batas '
                  '$maxReceipts struk.'),
          ];
        },
      ),
    );

    return ExportResult(
      bytes: await doc.save(),
      fileName: ExcelExporter.buildFileName(
        from: from,
        to: to,
        extension: 'pdf',
        prefix: 'kasbon_struk',
      ),
      mimeType: ExportResult.pdfMimeType,
      omittedRowCount: omitted,
    );
  }

  // ---------------------------------------------------------------------
  // Shared building blocks
  // ---------------------------------------------------------------------

  static pw.Widget _header({
    required pw.Context context,
    required String shopName,
    required String? shopAddress,
    required String? shopPhone,
    required String title,
    required DateTime from,
    required DateTime to,
  }) {
    // Repeating the full shop block on every page wastes space; later pages get
    // a compact running head instead.
    if (context.pageNumber > 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text(
          '$shopName - $title',
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
      );
    }

    final inclusiveEnd = to.subtract(const Duration(days: 1));
    final contactParts = [
      if (shopAddress != null && shopAddress.isNotEmpty) shopAddress,
      if (shopPhone != null && shopPhone.isNotEmpty) shopPhone,
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                shopName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (contactParts.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  contactParts.join(' - '),
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${_dateFormat.format(from)} - '
                '${_dateFormat.format(inclusiveEnd)}',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat ${_dateTimeFormat.format(DateTime.now())} - KASBON',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _note(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 8, color: _muted),
    );
  }

  static pw.Widget _statBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(color: _headerBg),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: _muted)),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryGrid(SalesSummary summary) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _statBox(
              'Total Pendapatan',
              CurrencyFormatter.format(summary.totalRevenue),
            ),
            pw.SizedBox(width: 10),
            _statBox(
              'Total Laba',
              CurrencyFormatter.format(summary.totalProfit),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _statBox('Transaksi', '${summary.transactionCount}'),
            pw.SizedBox(width: 10),
            _statBox('Item Terjual', '${summary.itemsSold}'),
            pw.SizedBox(width: 10),
            _statBox(
              'Margin Laba',
              '${summary.profitMargin.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ],
    );
  }

  static pw.TextStyle get _tableHeaderStyle =>
      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  static pw.TextStyle get _tableCellStyle => const pw.TextStyle(fontSize: 9);

  static pw.Widget _trendTable(List<SalesTrendPoint> trend) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Tanggal',
        'Transaksi',
        'Item',
        'Pendapatan',
        'Laba',
      ],
      data: trend
          .map((point) => [
                _dateFormat.format(point.bucketStart),
                '${point.transactionCount}',
                '${point.itemsSold}',
                CurrencyFormatter.format(point.revenue),
                CurrencyFormatter.format(point.profit),
              ])
          .toList(),
      headerStyle: _tableHeaderStyle,
      cellStyle: _tableCellStyle,
      headerDecoration: const pw.BoxDecoration(color: _headerBg),
      cellHeight: 18,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _categoryTable(List<CategorySlice> categories) {
    final total = categories.totalRevenue;

    return pw.TableHelper.fromTextArray(
      headers: const ['Kategori', 'Qty', 'Pendapatan', 'Laba', 'Porsi'],
      data: categories
          .map((slice) => [
                slice.categoryName,
                '${slice.quantitySold}',
                CurrencyFormatter.format(slice.revenue),
                CurrencyFormatter.format(slice.profit),
                total > 0
                    ? '${((slice.revenue / total) * 100).toStringAsFixed(1)}%'
                    : '-',
              ])
          .toList(),
      headerStyle: _tableHeaderStyle,
      cellStyle: _tableCellStyle,
      headerDecoration: const pw.BoxDecoration(color: _headerBg),
      cellHeight: 18,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _topProductsTable(List<ProductReport> products) {
    return pw.TableHelper.fromTextArray(
      headers: const ['#', 'Produk', 'Qty', 'Pendapatan', 'Laba'],
      data: [
        for (var i = 0; i < products.length; i++)
          [
            '${i + 1}',
            products[i].productName,
            '${products[i].quantitySold}',
            CurrencyFormatter.format(products[i].totalRevenue),
            CurrencyFormatter.format(products[i].totalProfit),
          ],
      ],
      headerStyle: _tableHeaderStyle,
      cellStyle: _tableCellStyle,
      headerDecoration: const pw.BoxDecoration(color: _headerBg),
      cellHeight: 18,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerRight,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _productTable(List<Product> products) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'SKU',
        'Produk',
        'Modal',
        'Jual',
        'Stok',
        'Nilai Stok',
      ],
      data: products
          .map((product) => [
                product.sku,
                product.name,
                CurrencyFormatter.format(product.costPrice),
                CurrencyFormatter.format(product.sellingPrice),
                '${product.stock} ${product.unit}',
                CurrencyFormatter.format(product.stock * product.costPrice),
              ])
          .toList(),
      headerStyle: _tableHeaderStyle,
      cellStyle: _tableCellStyle,
      headerDecoration: const pw.BoxDecoration(color: _headerBg),
      cellHeight: 18,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }
}
