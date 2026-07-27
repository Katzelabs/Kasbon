import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/core/services/export/excel_exporter.dart';
import 'package:kasbon_pos/core/services/export/export_result.dart';
import 'package:kasbon_pos/core/services/export/pdf_exporter.dart';
import 'package:kasbon_pos/features/products/domain/entities/product.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/reports/domain/entities/category_slice.dart';
import 'package:kasbon_pos/features/reports/domain/entities/product_report.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_summary.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction_item.dart';

final _from = DateTime(2026, 7);
final _to = DateTime(2026, 8);

Product _product(String name, {int stock = 10, bool active = true}) => Product(
      id: 'p-$name',
      sku: 'SKU-$name',
      name: name,
      costPrice: 5000,
      sellingPrice: 8000,
      stock: stock,
      minStock: 5,
      unit: 'pcs',
      isActive: active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TransactionItem _item(String name, {int qty = 2}) => TransactionItem(
      id: 'i-$name',
      transactionId: 't1',
      productId: 'p-$name',
      productName: name,
      productSku: 'SKU-$name',
      quantity: qty,
      costPrice: 5000,
      sellingPrice: 8000,
      subtotal: 8000.0 * qty,
      createdAt: DateTime(2026, 7, 5),
    );

Transaction _transaction(
  String number, {
  List<TransactionItem>? items,
  String? customer,
}) =>
    Transaction(
      id: 't-$number',
      transactionNumber: number,
      customerName: customer,
      subtotal: 16000,
      total: 16000,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      transactionDate: DateTime(2026, 7, 5, 14, 30),
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      items: items ?? [_item('Kopi')],
    );

final _summary = SalesSummary(
  totalRevenue: 1325400,
  totalProfit: 362500,
  transactionCount: 21,
  itemsSold: 162,
  periodStart: _from,
  periodEnd: _to,
);

final _shopSettings = ShopSettings(
  id: 's1',
  name: 'Warung Uji',
  address: 'Jl. Merdeka 1',
  phone: '08123456789',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The ZIP local-file-header magic that every .xlsx starts with.
const _zipMagic = [0x50, 0x4B, 0x03, 0x04];

/// `%PDF`
const _pdfMagic = [0x25, 0x50, 0x44, 0x46];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ExcelExporter', () {
    test('produces a real xlsx that can be decoded again', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: [_transaction('TRX-20260705-0001')],
        products: [_product('Kopi')],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.bytes.take(4), _zipMagic, reason: 'xlsx is a zip archive');
      expect(result.mimeType, ExportResult.xlsxMimeType);
      expect(result.sizeInBytes, greaterThan(0));

      // Round-tripping proves the workbook is structurally valid, not just
      // that some bytes were produced.
      final reopened = Excel.decodeBytes(result.bytes);
      expect(reopened.tables.keys,
          containsAll(['Ringkasan', 'Transaksi', 'Item Terjual', 'Produk']));
    });

    test('names the file with the inclusive end date', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: const [],
        products: const [],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      // `to` is exclusive (1 Aug), so the filename must read 31 Jul.
      expect(result.fileName, 'kasbon_laporan_20260701-20260731.xlsx');
    });

    test('leaves no stray default sheet behind', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: const [],
        products: const [],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      final reopened = Excel.decodeBytes(result.bytes);
      expect(reopened.tables.keys, isNot(contains('Sheet1')));
    });

    test('writes money as numbers so the columns stay summable', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: [_transaction('TRX-20260705-0001')],
        products: const [],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      final sheet = Excel.decodeBytes(result.bytes).tables['Transaksi']!;
      // Column 8 is 'Total (Rp)' on the first data row.
      final total = sheet.rows[1][8]?.value;

      // What matters is that the cell is numeric rather than a pre-formatted
      // "Rp 16.000" string, which a spreadsheet could not sum. Whether a whole
      // number round-trips as int or double is the library's choice.
      expect(total, anyOf(isA<IntCellValue>(), isA<DoubleCellValue>()));
      final numericValue = switch (total) {
        IntCellValue(:final value) => value.toDouble(),
        DoubleCellValue(:final value) => value,
        _ => null,
      };
      expect(numericValue, 16000);
    });

    test('flattens line items across transactions', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: [
          _transaction('TRX-1', items: [_item('Kopi'), _item('Teh')]),
          _transaction('TRX-2', items: [_item('Gula')]),
        ],
        products: const [],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      final sheet = Excel.decodeBytes(result.bytes).tables['Item Terjual']!;
      // One header row plus three item rows.
      expect(sheet.rows.length, 4);
    });

    test('handles a completely empty period', () {
      final result = ExcelExporter.buildWorkbook(
        transactions: const [],
        products: const [],
        summary: SalesSummary.empty(_from, _to),
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.bytes.take(4), _zipMagic);
      expect(result.isTruncated, isFalse);
    });

    test('reports truncation instead of silently dropping rows', () {
      final many = List.generate(
        ExcelExporter.maxTransactionRows + 25,
        (i) => _transaction('TRX-$i'),
      );

      final result = ExcelExporter.buildWorkbook(
        transactions: many,
        products: const [],
        summary: _summary,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.isTruncated, isTrue);
      expect(result.omittedRowCount, 25);
    });
  });

  group('PdfExporter', () {
    final trend = [
      SalesTrendPoint(
        bucketStart: DateTime(2026, 7, 5),
        granularity: TrendGranularity.day,
        revenue: 133000,
        profit: 29000,
        transactionCount: 2,
        itemsSold: 6,
      ),
    ];

    const categories = [
      CategorySlice(
        categoryId: 'c1',
        categoryName: 'Makanan',
        categoryColor: '#FF6B35',
        revenue: 682500,
        profit: 166000,
        quantitySold: 82,
      ),
    ];

    const topProducts = [
      ProductReport(
        productId: 'p1',
        productName: 'Telur Ayam',
        quantitySold: 45,
        totalRevenue: 126000,
        totalProfit: 36000,
      ),
    ];

    test('produces a valid PDF for the sales report', () async {
      final result = await PdfExporter.buildSalesReport(
        summary: _summary,
        trend: trend,
        categories: categories,
        topProducts: topProducts,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
        shopAddress: 'Jl. Merdeka 1',
        shopPhone: '08123456789',
      );

      expect(result.bytes.take(4), _pdfMagic);
      expect(result.mimeType, ExportResult.pdfMimeType);
      expect(result.fileName, 'kasbon_penjualan_20260701-20260731.pdf');
      expect(result.sizeInBytes, greaterThan(1000));
    });

    test('renders with every optional section empty', () async {
      // A brand new shop has no trend, no categories and no best sellers - the
      // document still has to build rather than throwing on empty tables.
      final result = await PdfExporter.buildSalesReport(
        summary: SalesSummary.empty(_from, _to),
        trend: const [],
        categories: const [],
        topProducts: const [],
        from: _from,
        to: _to,
        shopName: 'Toko Baru',
      );

      expect(result.bytes.take(4), _pdfMagic);
    });

    test('renders without shop address or phone', () async {
      final result = await PdfExporter.buildSalesReport(
        summary: _summary,
        trend: trend,
        categories: categories,
        topProducts: topProducts,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.bytes.take(4), _pdfMagic);
    });

    test('produces a valid PDF for the product report', () async {
      final result = await PdfExporter.buildProductReport(
        products: [_product('Kopi'), _product('Teh', stock: 2)],
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.bytes.take(4), _pdfMagic);
      expect(result.fileName, 'kasbon_produk_20260701-20260731.pdf');
    });

    test('compiles receipts into a single valid PDF', () async {
      final result = await PdfExporter.buildReceiptCompilation(
        transactions: [
          _transaction('TRX-20260705-0001', customer: 'Bu Siti'),
          _transaction('TRX-20260705-0002'),
        ],
        shopSettings: _shopSettings,
        from: _from,
        to: _to,
      );

      expect(result.bytes.take(4), _pdfMagic);
      expect(result.fileName, 'kasbon_struk_20260701-20260731.pdf');
      expect(result.isTruncated, isFalse);
    });

    test('renders a receipt archive for a period with no sales', () async {
      final result = await PdfExporter.buildReceiptCompilation(
        transactions: const [],
        shopSettings: _shopSettings,
        from: _from,
        to: _to,
      );

      expect(result.bytes.take(4), _pdfMagic);
    });

    test('caps the receipt archive and reports the overflow', () async {
      final many = List.generate(
        PdfExporter.maxReceipts + 7,
        (i) => _transaction('TRX-$i'),
      );

      final result = await PdfExporter.buildReceiptCompilation(
        transactions: many,
        shopSettings: _shopSettings,
        from: _from,
        to: _to,
      );

      expect(result.bytes.take(4), _pdfMagic);
      expect(result.omittedRowCount, 7);
    });

    test('paginates a long product list and reports truncation', () async {
      final many = List.generate(
        PdfExporter.maxTableRows + 10,
        (i) => _product('Produk $i'),
      );

      final result = await PdfExporter.buildProductReport(
        products: many,
        from: _from,
        to: _to,
        shopName: 'Toko Uji',
      );

      expect(result.bytes.take(4), _pdfMagic);
      expect(result.isTruncated, isTrue);
      expect(result.omittedRowCount, 10);
    });
  });
}
