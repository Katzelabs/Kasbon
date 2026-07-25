import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/core/utils/receipt_generator.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction_item.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';

import '../../../fixtures/mock_data.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ReceiptGenerator', () {
    late ShopSettings shopSettings;
    late Transaction transaction;
    late DateTime fixedDate;

    setUp(() {
      fixedDate = DateTime(2026, 1, 26, 14, 30);

      shopSettings = MockData.createShopSettings(
        name: 'Toko Test',
        address: 'Jl. Test No. 123',
        phone: '081234567890',
        receiptFooter: 'Terima kasih!',
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );

      transaction = MockData.createTransaction(
        transactionNumber: 'TRX-20260126-0001',
        subtotal: 30000,
        total: 30000,
        cashReceived: 50000,
        cashChange: 20000,
        transactionDate: fixedDate,
        items: [
          MockData.createTransactionItem(
            productName: 'Mie Goreng',
            quantity: 2,
            sellingPrice: 15000,
            subtotal: 30000,
          ),
        ],
      );
    });

    group('generate', () {
      test('generates receipt with correct width (42 characters)', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        // Check that divider lines are 42 characters
        expect(receipt.contains('=' * 42), true);
        expect(receipt.contains('-' * 42), true);
      });

      test('includes shop name in header', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('TOKO TEST'), true);
      });

      test('includes shop address when present', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Jl. Test No. 123'), true);
      });

      test('includes shop phone when present', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('081234567890'), true);
      });

      test('includes transaction number', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('No: TRX-20260126-0001'), true);
      });

      test('includes transaction date', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Tanggal:'), true);
        expect(receipt.contains('26'), true);
      });

      test('includes item details', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Mie Goreng'), true);
        expect(receipt.contains('2 x'), true);
      });

      test('includes subtotal', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Subtotal'), true);
      });

      test('includes total', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('TOTAL'), true);
      });

      test('includes cash received for paid transactions', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Uang Diterima'), true);
        expect(receipt.contains('Kembalian'), true);
      });

      test('includes payment method', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Metode'), true);
        expect(receipt.contains('Tunai'), true);
      });

      test('includes custom footer when present', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Terima kasih!'), true);
      });

      test('includes app branding', () {
        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Powered by KASBON'), true);
      });
    });

    group('debt transactions', () {
      late Transaction debtTransaction;

      setUp(() {
        debtTransaction = MockData.debtTransaction(
          transactionNumber: 'TRX-20260126-0002',
          customerName: 'Pak Budi',
          total: 50000,
          items: [
            MockData.createTransactionItem(
              productName: 'Beras 5kg',
              quantity: 1,
              sellingPrice: 50000,
              subtotal: 50000,
            ),
          ],
        );
      });

      test('shows debt indicator for debt transactions', () {
        final receipt = ReceiptGenerator.generate(
          transaction: debtTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('** HUTANG **'), true);
      });

      test('shows unpaid status for debt transactions', () {
        final receipt = ReceiptGenerator.generate(
          transaction: debtTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Belum Lunas'), true);
      });

      test('does not show cash received for debt transactions', () {
        final receipt = ReceiptGenerator.generate(
          transaction: debtTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Uang Diterima'), false);
        expect(receipt.contains('Kembalian'), false);
      });

      test('includes customer name for debt transactions', () {
        final receipt = ReceiptGenerator.generate(
          transaction: debtTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Pelanggan: Pak Budi'), true);
      });
    });

    group('discount handling', () {
      test('shows discount when present', () {
        final discountTransaction = MockData.createTransaction(
          subtotal: 30000,
          discountAmount: 5000,
          total: 25000,
          items: [
            MockData.createTransactionItem(
              productName: 'Test Product',
              quantity: 1,
              sellingPrice: 30000,
              subtotal: 30000,
            ),
          ],
        );

        final receipt = ReceiptGenerator.generate(
          transaction: discountTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Diskon'), true);
      });

      test('does not show discount when zero', () {
        final noDiscountTransaction = MockData.createTransaction(
          subtotal: 30000,
          discountAmount: 0,
          total: 30000,
          items: [
            MockData.createTransactionItem(
              productName: 'Test Product',
              quantity: 1,
              sellingPrice: 30000,
              subtotal: 30000,
            ),
          ],
        );

        final receipt = ReceiptGenerator.generate(
          transaction: noDiscountTransaction,
          shopSettings: shopSettings,
        );

        // Count occurrences - Diskon should not appear when amount is 0
        final diskonCount = 'Diskon'.allMatches(receipt).length;
        expect(diskonCount, 0);
      });
    });

    group('minimal shop settings', () {
      test('generates receipt without optional fields', () {
        final minimalSettings = MockData.minimalShopSettings(
          name: 'Toko Minimal',
        );

        final receipt = ReceiptGenerator.generate(
          transaction: transaction,
          shopSettings: minimalSettings,
        );

        expect(receipt.contains('TOKO MINIMAL'), true);
        expect(receipt.contains('Terima kasih atas kunjungannya!'), true);
      });
    });

    group('multiple items', () {
      test('shows all items in receipt', () {
        final multiItemTransaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(
              productName: 'Produk A',
              quantity: 1,
              sellingPrice: 10000,
              subtotal: 10000,
            ),
            MockData.createTransactionItem(
              id: 'item-2',
              productId: 'prod-2',
              productName: 'Produk B',
              productSku: 'SKU-2',
              quantity: 2,
              sellingPrice: 15000,
              subtotal: 30000,
            ),
            MockData.createTransactionItem(
              id: 'item-3',
              productId: 'prod-3',
              productName: 'Produk C',
              productSku: 'SKU-3',
              quantity: 3,
              sellingPrice: 20000,
              subtotal: 60000,
            ),
          ],
        );

        final receipt = ReceiptGenerator.generate(
          transaction: multiItemTransaction,
          shopSettings: shopSettings,
        );

        expect(receipt.contains('Produk A'), true);
        expect(receipt.contains('Produk B'), true);
        expect(receipt.contains('Produk C'), true);
      });
    });

    group('long product names', () {
      test('truncates long product names', () {
        final longNameTransaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(
              productName:
                  'This is a very long product name that exceeds the receipt width limit',
              quantity: 1,
              sellingPrice: 10000,
              subtotal: 10000,
            ),
          ],
        );

        final receipt = ReceiptGenerator.generate(
          transaction: longNameTransaction,
          shopSettings: shopSettings,
        );

        // Should contain truncated name with ellipsis
        expect(receipt.contains('...'), true);
      });
    });

    group('receiptWidth constant', () {
      test('receiptWidth is 42', () {
        expect(ReceiptGenerator.receiptWidth, 42);
      });
    });
  });
}
