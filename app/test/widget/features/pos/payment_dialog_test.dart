import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/services/payment_proof/payment_proof_storage.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/cart_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/customer_names_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/payment_provider.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/debt_payment_dialog.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/payment_dialog.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/font_helpers.dart';
import '../../../helpers/responsive_helpers.dart';

/// Characterisation tests for the payment dialog as it behaves *today*.
///
/// Written before the dialog is restructured to carry QRIS and the optional
/// customer/notes fields. Every expectation here describes existing behaviour,
/// so a failure after the restructure means the restructure changed something
/// a cashier can see - not that the test is wrong.
///
/// The two things most at risk are the money guard (never take a payment for
/// less than the total) and the keyboard path (a cashier finishes a sale
/// without leaving the number pad), so those carry the most cases.

/// Stands in for the real notifier so the dialog can be driven without GetIt,
/// a Supabase client, or a cart.
///
/// Recording rather than mocking: the question these tests ask is "did the
/// dialog decide to take money, and how much", which is exactly one list.
class _RecordingPaymentNotifier extends PaymentNotifier {
  _RecordingPaymentNotifier(super.ref);

  final List<double> cashPayments = [];
  final List<_QrisCall> qrisPayments = [];

  /// Names and notes the dialog passed along, whichever method was used.
  String? lastCustomerName;
  String? lastNotes;

  @override
  Future<void> processCashPayment({
    required double cashReceived,
    String? customerName,
    String? notes,
  }) async {
    cashPayments.add(cashReceived);
    lastCustomerName = customerName;
    lastNotes = notes;
    state = PaymentState(
      completedTransaction: MockData.createTransaction(total: cashReceived),
    );
  }

  @override
  Future<void> processQrisPayment({
    PickedImage? proof,
    String? customerName,
    String? notes,
  }) async {
    qrisPayments.add(_QrisCall(hasProof: proof != null));
    lastCustomerName = customerName;
    lastNotes = notes;
    state = PaymentState(
      completedTransaction: MockData.createTransaction(
        paymentMethod: PaymentMethod.qris,
      ),
    );
  }
}

class _QrisCall {
  const _QrisCall({required this.hasProof});

  final bool hasProof;
}

void main() {
  // These run at compact width, where the dialog is tightest. That is only
  // meaningful with the real typeface loaded - see loadAppFonts.
  setUpAll(loadAppFonts);

  /// Opens the dialog over a stand-in POS screen and returns the notifier that
  /// recorded whatever it did.
  ///
  /// The dialog has to be pushed as a real route rather than pumped directly:
  /// it pops itself on success, and a directly-pumped widget has no route to
  /// pop.
  Future<_RecordingPaymentNotifier> openDialog(
    WidgetTester tester, {
    double total = 20000,
  }) async {
    late _RecordingPaymentNotifier notifier;

    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      Builder(
        builder: (context) => Column(
          children: [
            const Text('POS'),
            TextButton(
              onPressed: () => PaymentDialog.show(context),
              child: const Text('buka'),
            ),
          ],
        ),
      ),
      providerOverrides: [
        cartTotalProvider.overrideWithValue(total),
        paymentProvider.overrideWith((ref) {
          notifier = _RecordingPaymentNotifier(ref);
          return notifier;
        }),
      ],
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentDialog), findsOneWidget);

    return notifier;
  }

  /// Types [amount] into the "Uang Diterima" field.
  ///
  /// Targets the field by its label rather than by type: expanding the
  /// optional fields puts two more TextFormFields in the tree, and a bare
  /// byType finder starts matching all three.
  Future<void> enterCash(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Uang Diterima'),
      amount,
    );
    await tester.pumpAndSettle();
  }

  group('the money guard', () {
    testWidgets('will not take a payment before any cash is entered',
        (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
      expect(find.byType(PaymentDialog), findsOneWidget);
    });

    testWidgets('will not take a payment for less than the total',
        (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '15000');
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
    });

    testWidgets('takes exact payment', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '20000');
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, [20000]);
    });

    testWidgets('takes overpayment and leaves change', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '50000');
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, [50000]);
    });
  });

  group('the change panel', () {
    testWidgets('is absent until cash is entered', (tester) async {
      await openDialog(tester, total: 20000);

      expect(find.text('Kembalian'), findsNothing);
      expect(find.text('Kurang'), findsNothing);
    });

    testWidgets('names the change when the cash covers the total',
        (tester) async {
      await openDialog(tester, total: 20000);

      await enterCash(tester, '50000');

      expect(find.text('Kembalian'), findsOneWidget);
      expect(find.text('Rp30.000'), findsOneWidget);
    });

    // A shortfall is not change of a negative amount - it is a different thing
    // and reads differently, or a cashier hands back money they never took.
    testWidgets('names the shortfall when the cash does not', (tester) async {
      await openDialog(tester, total: 20000);

      await enterCash(tester, '15000');

      expect(find.text('Kurang'), findsOneWidget);
      expect(find.text('Rp5.000'), findsOneWidget);
      expect(find.text('Kembalian'), findsNothing);
    });
  });

  group('the quick cash row', () {
    testWidgets('fills the field with the note tapped', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await tester.tap(find.text('Rp50.0rb'));
      await tester.pumpAndSettle();

      expect(find.text('Kembalian'), findsOneWidget);
      expect(find.text('Rp30.000'), findsOneWidget);

      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();
      expect(notifier.cashPayments, [50000]);
    });

    testWidgets('"Uang Pas" fills the exact total', (tester) async {
      final notifier = await openDialog(tester, total: 17500);

      await tester.tap(find.text('Uang Pas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, [17500]);
    });
  });

  group('the keyboard path', () {
    // The cash field owns Enter while it has focus, so the fast path is wired
    // on the field as well as on the dialog. This is the field's copy.
    testWidgets('Enter in the cash field takes the payment', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '20000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, [20000]);
    });

    testWidgets('Enter does nothing while the cash is short', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '15000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
      expect(find.byType(PaymentDialog), findsOneWidget);
    });

    // A double Enter must not submit twice - the guard is `isProcessing`.
    testWidgets('a second Enter does not take a second payment',
        (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '20000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, hasLength(1));
    });

    testWidgets('Esc closes the dialog without taking anything',
        (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await enterCash(tester, '50000');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
      expect(find.byType(PaymentDialog), findsNothing);
      expect(find.text('POS'), findsOneWidget);
    });
  });

  group('dismissal', () {
    testWidgets('the close button leaves the POS grid behind', (tester) async {
      final notifier = await openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
      expect(find.byType(PaymentDialog), findsNothing);
      expect(find.text('POS'), findsOneWidget);
    });

    testWidgets('"Batal" leaves the POS grid behind', (tester) async {
      final notifier = await openDialog(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(notifier.cashPayments, isEmpty);
      expect(find.byType(PaymentDialog), findsNothing);
      expect(find.text('POS'), findsOneWidget);
    });
  });

  group('QRIS', () {
    /// Switches the dialog to QRIS.
    Future<void> chooseQris(WidgetTester tester) async {
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();
    }

    testWidgets('drops the cash field - there is no amount to enter',
        (tester) async {
      await openDialog(tester, total: 20000);
      expect(find.text('Uang Diterima'), findsOneWidget);

      await chooseQris(tester);

      // The customer types the total into their own wallet app; this app never
      // sees it, so an amount field here would be a lie.
      expect(find.text('Uang Diterima'), findsNothing);
      expect(find.text('Uang Pas'), findsNothing);
      expect(find.text('Kembalian'), findsNothing);
    });

    testWidgets('tells the cashier what to say, including the total',
        (tester) async {
      await openDialog(tester, total: 20000);
      await chooseQris(tester);

      expect(find.text('Minta pelanggan scan QRIS di meja'), findsOneWidget);
      expect(find.text('lalu masukkan Rp20.000'), findsOneWidget);
    });

    // Confirming is the whole transaction: no amount to validate, so the
    // button is live the moment QRIS is chosen.
    testWidgets('confirms without any input', (tester) async {
      final notifier = await openDialog(tester, total: 20000);
      await chooseQris(tester);

      await tester.tap(find.text('Sudah Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.qrisPayments, hasLength(1));
      expect(notifier.cashPayments, isEmpty);
    });

    testWidgets('takes the sale with no photo attached', (tester) async {
      final notifier = await openDialog(tester);
      await chooseQris(tester);

      await tester.tap(find.text('Sudah Bayar'));
      await tester.pumpAndSettle();

      // A proof is optional. A cashier with a queue should never be blocked on
      // getting a photograph of somebody else's phone.
      expect(notifier.qrisPayments.single.hasProof, isFalse);
    });

    testWidgets('offers to photograph the proof', (tester) async {
      await openDialog(tester);
      await chooseQris(tester);

      expect(find.text('Foto Bukti (opsional)'), findsOneWidget);
    });

    testWidgets('switching back to cash restores the amount field',
        (tester) async {
      await openDialog(tester, total: 20000);
      await chooseQris(tester);
      expect(find.text('Uang Diterima'), findsNothing);

      await tester.tap(find.text('Tunai'));
      await tester.pumpAndSettle();

      expect(find.text('Uang Diterima'), findsOneWidget);
      expect(find.text('Sudah Bayar'), findsNothing);
      expect(find.text('Bayar'), findsOneWidget);
    });
  });

  group('the optional fields', () {
    testWidgets('are collapsed until asked for', (tester) async {
      await openDialog(tester);

      // The hot path is tap-type-Enter. Two permanent text fields between the
      // amount and the Bayar button would push the button off a phone screen.
      expect(find.text('Catatan / nama pelanggan'), findsOneWidget);
      expect(find.text('Nama Pelanggan (opsional)'), findsNothing);
      expect(find.text('Catatan (opsional)'), findsNothing);
    });

    testWidgets('expand on tap', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Catatan / nama pelanggan'));
      await tester.pumpAndSettle();

      expect(find.text('Nama Pelanggan (opsional)'), findsOneWidget);
      expect(find.text('Catatan (opsional)'), findsOneWidget);
    });

    testWidgets('reach the cash sale that was recorded', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await tester.tap(find.text('Catatan / nama pelanggan'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Pelanggan (opsional)'),
          'Bu Sri');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Catatan (opsional)'),
          'titip dulu');
      await enterCash(tester, '20000');

      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.lastCustomerName, 'Bu Sri');
      expect(notifier.lastNotes, 'titip dulu');
    });

    testWidgets('reach a QRIS sale too', (tester) async {
      final notifier = await openDialog(tester);

      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catatan / nama pelanggan'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Pelanggan (opsional)'),
          'Pak Ahmad');

      await tester.tap(find.text('Sudah Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.lastCustomerName, 'Pak Ahmad');
    });

    // Reproduces the reported bug in the place it was reported: the chip in
    // the dialog, not the field in isolation.
    testWidgets('a tapped suggestion chip reaches the sale', (tester) async {
      late _RecordingPaymentNotifier notifier;

      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        Builder(
          builder: (context) => Column(
            children: [
              const Text('POS'),
              TextButton(
                onPressed: () => PaymentDialog.show(context),
                child: const Text('buka'),
              ),
            ],
          ),
        ),
        providerOverrides: [
          cartTotalProvider.overrideWithValue(20000),
          customerNamesProvider.overrideWith((ref) async => ['Bu Sri']),
          paymentProvider.overrideWith((ref) {
            notifier = _RecordingPaymentNotifier(ref);
            return notifier;
          }),
        ],
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catatan / nama pelanggan'));
      await tester.pumpAndSettle();

      // Focus the name field so the suggestions appear.
      await tester.tap(
          find.widgetWithText(TextFormField, 'Nama Pelanggan (opsional)'));
      await tester.pumpAndSettle();
      expect(find.text('Bu Sri'), findsOneWidget);

      await tester.tap(find.text('Bu Sri'));
      await tester.pumpAndSettle();

      await enterCash(tester, '20000');
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.lastCustomerName, 'Bu Sri');
    });

    // Whitespace is not a customer name, and storing " " would put a blank row
    // in the autocomplete for every sale someone tabbed through.
    testWidgets('send null rather than blank text', (tester) async {
      final notifier = await openDialog(tester, total: 20000);

      await tester.tap(find.text('Catatan / nama pelanggan'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Pelanggan (opsional)'),
          '   ');
      await enterCash(tester, '20000');

      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      expect(notifier.lastCustomerName, isNull);
      expect(notifier.lastNotes, isNull);
    });
  });

  group('switching to hutang', () {
    // Hutang is not a mode of this dialog - it closes and hands over to one
    // that can require a customer name.
    testWidgets('closes this dialog and opens the debt one', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Hutang'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentDialog), findsNothing);
      expect(find.byType(DebtPaymentDialog), findsOneWidget);
    });
  });
}
