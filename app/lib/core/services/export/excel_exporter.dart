import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../../features/products/domain/entities/product.dart';
import '../../../features/reports/domain/entities/sales_summary.dart';
import '../../../features/transactions/domain/entities/transaction.dart';
import '../../errors/exceptions.dart';
import 'export_result.dart';

/// Builds an .xlsx workbook from report data.
///
/// Money is written as raw numbers rather than pre-formatted "Rp 1.000"
/// strings. A shop owner opening this in Excel or Google Sheets will want to
/// sum and filter the columns, which text cells make impossible; the currency
/// is stated in the column header instead.
class ExcelExporter {
  ExcelExporter._();

  /// Maximum transaction rows written before truncating.
  ///
  /// excel 3.x holds the whole workbook in memory and is slow on large sheets,
  /// so a very long history would hang the app rather than fail. Anything
  /// dropped is reported via [ExportResult.omittedRowCount].
  static const int maxTransactionRows = 5000;

  static final DateFormat _dateTimeFormat =
      DateFormat('yyyy-MM-dd HH:mm', 'id_ID');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd', 'id_ID');
  static final DateFormat _fileStampFormat = DateFormat('yyyyMMdd');

  /// Build a workbook with a summary, transaction and product sheet.
  ///
  /// [transactions] must already carry their line items; the item sheet is
  /// derived from them rather than re-queried.
  static ExportResult buildWorkbook({
    required List<Transaction> transactions,
    required List<Product> products,
    required SalesSummary summary,
    required DateTime from,
    required DateTime to,
    required String shopName,
  }) {
    final excel = Excel.createExcel();

    // createExcel() seeds a default sheet; renaming it avoids ending up with a
    // stray empty "Sheet1" alongside the real ones.
    excel.rename(excel.getDefaultSheet()!, 'Ringkasan');

    final omitted = transactions.length > maxTransactionRows
        ? transactions.length - maxTransactionRows
        : 0;
    final visibleTransactions = omitted > 0
        ? transactions.sublist(0, maxTransactionRows)
        : transactions;

    _buildSummarySheet(
      excel['Ringkasan'],
      summary: summary,
      from: from,
      to: to,
      shopName: shopName,
      transactionCount: transactions.length,
      productCount: products.length,
      omittedRows: omitted,
    );
    _buildTransactionSheet(excel['Transaksi'], visibleTransactions);
    _buildItemSheet(excel['Item Terjual'], visibleTransactions);
    _buildProductSheet(excel['Produk'], products);

    final encoded = excel.encode();
    if (encoded == null) {
      throw const FileException(message: 'Gagal membuat berkas Excel');
    }

    return ExportResult(
      bytes: Uint8List.fromList(encoded),
      fileName: buildFileName(from: from, to: to, extension: 'xlsx'),
      mimeType: ExportResult.xlsxMimeType,
      omittedRowCount: omitted,
    );
  }

  /// `kasbon_laporan_20260601-20260731.xlsx`
  ///
  /// [to] is exclusive in the report range, so a day is subtracted to give the
  /// inclusive end date a reader expects in a filename.
  static String buildFileName({
    required DateTime from,
    required DateTime to,
    required String extension,
    String prefix = 'kasbon_laporan',
  }) {
    final inclusiveEnd = to.subtract(const Duration(days: 1));
    return '${prefix}_${_fileStampFormat.format(from)}-'
        '${_fileStampFormat.format(inclusiveEnd)}.$extension';
  }

  static CellStyle get _headerStyle => CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('FF2563EB'),
        horizontalAlign: HorizontalAlign.Center,
      );

  static CellStyle get _labelStyle => CellStyle(bold: true);

  /// Wrap a Dart value in the matching [CellValue].
  ///
  /// Numbers deliberately become numeric cells rather than text, so the
  /// currency columns stay summable in a spreadsheet app. A null becomes an
  /// empty cell rather than the string "null".
  static CellValue? _toCellValue(Object? value) {
    return switch (value) {
      null => null,
      int v => IntCellValue(v),
      double v => DoubleCellValue(v),
      String v => TextCellValue(v),
      _ => TextCellValue(value.toString()),
    };
  }

  static void _setCell(
    Sheet sheet,
    int column,
    int row,
    Object? value, {
    CellStyle? style,
  }) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      _toCellValue(value),
      cellStyle: style,
    );
  }

  static void _writeHeaderRow(Sheet sheet, List<String> headers, int row) {
    for (var i = 0; i < headers.length; i++) {
      _setCell(sheet, i, row, headers[i], style: _headerStyle);
    }
  }

  static void _buildSummarySheet(
    Sheet sheet, {
    required SalesSummary summary,
    required DateTime from,
    required DateTime to,
    required String shopName,
    required int transactionCount,
    required int productCount,
    required int omittedRows,
  }) {
    final inclusiveEnd = to.subtract(const Duration(days: 1));
    var row = 0;

    _setCell(sheet, 0, row, shopName, style: _labelStyle);
    row += 1;
    _setCell(sheet, 0, row, 'Laporan Penjualan', style: _labelStyle);
    row += 2;

    final rows = <List<Object?>>[
      [
        'Periode',
        '${_dateFormat.format(from)} s/d '
            '${_dateFormat.format(inclusiveEnd)}'
      ],
      ['Dibuat pada', _dateTimeFormat.format(DateTime.now())],
      ['Total Pendapatan (Rp)', summary.totalRevenue],
      ['Total Laba (Rp)', summary.totalProfit],
      ['Margin Laba (%)', summary.profitMargin],
      ['Jumlah Transaksi', summary.transactionCount],
      ['Item Terjual', summary.itemsSold],
      ['Rata-rata per Transaksi (Rp)', summary.averageTransactionValue],
      ['Jumlah Produk', productCount],
    ];

    for (final entry in rows) {
      _setCell(sheet, 0, row, entry[0], style: _labelStyle);
      _setCell(sheet, 1, row, entry[1]);
      row += 1;
    }

    if (omittedRows > 0) {
      row += 1;
      _setCell(
        sheet,
        0,
        row,
        'Catatan: $omittedRows transaksi tidak dimuat '
        '(batas $maxTransactionRows baris). Persempit rentang tanggal '
        'untuk mengekspor sisanya.',
        style: _labelStyle,
      );
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 28);
  }

  static void _buildTransactionSheet(
    Sheet sheet,
    List<Transaction> transactions,
  ) {
    const headers = [
      'No. Transaksi',
      'Tanggal',
      'Pelanggan',
      'Metode Bayar',
      'Status',
      'Subtotal (Rp)',
      'Diskon (Rp)',
      'Pajak (Rp)',
      'Total (Rp)',
      'Jumlah Item',
      'Catatan',
    ];
    _writeHeaderRow(sheet, headers, 0);

    for (var i = 0; i < transactions.length; i++) {
      final txn = transactions[i];
      final row = i + 1;
      final itemCount =
          txn.items.fold<int>(0, (sum, item) => sum + item.quantity);

      _setCell(sheet, 0, row, txn.transactionNumber);
      _setCell(sheet, 1, row, _dateTimeFormat.format(txn.transactionDate));
      _setCell(sheet, 2, row, txn.customerName ?? '-');
      _setCell(sheet, 3, row, txn.paymentMethod.label);
      _setCell(sheet, 4, row, txn.paymentStatus.label);
      _setCell(sheet, 5, row, txn.subtotal);
      _setCell(sheet, 6, row, txn.discountAmount);
      _setCell(sheet, 7, row, txn.taxAmount);
      _setCell(sheet, 8, row, txn.total);
      _setCell(sheet, 9, row, itemCount);
      _setCell(sheet, 10, row, txn.notes ?? '');
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 0 ? 22 : 16);
    }
  }

  /// Line items flattened across transactions.
  ///
  /// Kept on its own sheet so a shop can pivot by product without unpacking
  /// nested rows, which a single flat transaction sheet cannot express.
  static void _buildItemSheet(Sheet sheet, List<Transaction> transactions) {
    const headers = [
      'No. Transaksi',
      'Tanggal',
      'SKU',
      'Produk',
      'Qty',
      'Harga Modal (Rp)',
      'Harga Jual (Rp)',
      'Subtotal (Rp)',
      'Laba (Rp)',
    ];
    _writeHeaderRow(sheet, headers, 0);

    var row = 1;
    for (final txn in transactions) {
      for (final item in txn.items) {
        final profit = (item.sellingPrice - item.costPrice) * item.quantity;

        _setCell(sheet, 0, row, txn.transactionNumber);
        _setCell(sheet, 1, row, _dateTimeFormat.format(txn.transactionDate));
        _setCell(sheet, 2, row, item.productSku);
        _setCell(sheet, 3, row, item.productName);
        _setCell(sheet, 4, row, item.quantity);
        _setCell(sheet, 5, row, item.costPrice);
        _setCell(sheet, 6, row, item.sellingPrice);
        _setCell(sheet, 7, row, item.subtotal);
        _setCell(sheet, 8, row, profit);
        row += 1;
      }
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 3 ? 28 : 16);
    }
  }

  static void _buildProductSheet(Sheet sheet, List<Product> products) {
    const headers = [
      'SKU',
      'Nama Produk',
      'Barcode',
      'Harga Modal (Rp)',
      'Harga Jual (Rp)',
      'Margin (Rp)',
      'Stok',
      'Stok Minimum',
      'Satuan',
      'Nilai Stok (Rp)',
      'Status',
    ];
    _writeHeaderRow(sheet, headers, 0);

    for (var i = 0; i < products.length; i++) {
      final product = products[i];
      final row = i + 1;

      _setCell(sheet, 0, row, product.sku);
      _setCell(sheet, 1, row, product.name);
      _setCell(sheet, 2, row, product.barcode ?? '');
      _setCell(sheet, 3, row, product.costPrice);
      _setCell(sheet, 4, row, product.sellingPrice);
      _setCell(sheet, 5, row, product.sellingPrice - product.costPrice);
      _setCell(sheet, 6, row, product.stock);
      _setCell(sheet, 7, row, product.minStock);
      _setCell(sheet, 8, row, product.unit);
      _setCell(sheet, 9, row, product.stock * product.costPrice);
      _setCell(sheet, 10, row, product.isActive ? 'Aktif' : 'Nonaktif');
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 1 ? 28 : 16);
    }
  }
}
