import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/transaction_success_dialog.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

void main() {
  group('cash sale', () {
    testWidgets('shows the number, the total and the change to hand back',
        (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        TransactionSuccessDialog(
          transaction: MockData.createTransaction(
            transactionNumber: 'TRX-20260730-0007',
            total: 20000,
            cashReceived: 50000,
            cashChange: 30000,
          ),
        ),
      );

      expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
      expect(find.text('TRX-20260730-0007'), findsOneWidget);
      expect(find.text('Rp20.000'), findsOneWidget);
      expect(find.text('Uang Diterima'), findsOneWidget);
      expect(find.text('Rp50.000'), findsOneWidget);
      expect(find.text('Kembalian'), findsOneWidget);
      expect(find.text('Rp30.000'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
    });
  });

  group('debt sale', () {
    // A hutang has no cash and no change; showing "Kembalian Rp0" would read as
    // a cash sale that happened to come out even.
    testWidgets('names the customer instead of the change', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        TransactionSuccessDialog(
          transaction: MockData.debtTransaction(
            customerName: 'Bu Siti',
            total: 15000,
          ),
        ),
      );

      expect(find.text('Hutang Tercatat'), findsOneWidget);
      expect(find.text('Pelanggan'), findsOneWidget);
      expect(find.text('Bu Siti'), findsOneWidget);
      expect(find.text('Kembalian'), findsNothing);
      expect(find.text('Uang Diterima'), findsNothing);
    });
  });

  group('dismissal', () {
    /// Opens the modal over a stand-in POS screen.
    Future<void> pumpAndOpen(WidgetTester tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        Builder(
          builder: (context) => Column(
            children: [
              const Text('POS'),
              TextButton(
                onPressed: () => TransactionSuccessDialog.show(
                  context,
                  MockData.createTransaction(),
                ),
                child: const Text('bayar'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('bayar'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionSuccessDialog), findsOneWidget);
    }

    // The whole point of the modal replacing the old `/pos/success/:id` route:
    // finishing a sale leaves the cashier on the POS grid, not one back-press
    // away from it. Both exits land in the same place.
    for (final exit in {
      '"Transaksi Baru"': find.text('Transaksi Baru'),
      'the close button': find.byIcon(Icons.close),
    }.entries) {
      testWidgets('${exit.key} closes it and reveals what is behind',
          (tester) async {
        await pumpAndOpen(tester);

        await tester.tap(exit.value);
        await tester.pumpAndSettle();

        expect(find.byType(TransactionSuccessDialog), findsNothing);
        expect(find.text('POS'), findsOneWidget);
      });
    }
  });
}
