import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/presentation/providers/payment_proof_provider.dart';
import 'package:kasbon_pos/features/transactions/presentation/widgets/payment_proof_card.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/font_helpers.dart';
import '../../../helpers/responsive_helpers.dart';

/// The card's two states, and which sales get one at all.
///
/// The empty state carries the weight here. A QRIS proof can be missing for two
/// entirely ordinary reasons - the cashier skipped it with a queue waiting, or
/// the background upload lost a flat connection - and neither interrupts anyone
/// at the time. This card is the only place either becomes visible, so "shows
/// a way to fix it" is the actual requirement, not a nicety.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    // The confirmation line formats a time, and DateFormat throws without it.
    // main.dart does the same at startup.
    await initializeDateFormatting('id_ID', null);
  });

  Transaction qris({String? proofPath, DateTime? confirmedAt}) {
    return MockData.createTransaction(
      paymentMethod: PaymentMethod.qris,
    ).copyWith(
      paymentProofPath: proofPath,
      paymentConfirmedAt: confirmedAt,
      paymentConfirmedBy:
          confirmedAt == null ? null : PaymentConfirmedBy.cashier,
    );
  }

  group('appliesTo', () {
    test('covers a QRIS sale', () {
      expect(PaymentProofCard.appliesTo(qris()), isTrue);
    });

    // Notes in the drawer are their own evidence. A card inviting the owner to
    // photograph something would appear on every cash sale in the history.
    test('skips a cash sale', () {
      expect(
        PaymentProofCard.appliesTo(MockData.createTransaction()),
        isFalse,
      );
    });

    // If a proof somehow exists, show it whatever the method says - hiding
    // stored evidence because of a category rule would be worse than an
    // unexpected card.
    test('covers any sale that already has a proof', () {
      final cashWithProof = MockData.createTransaction()
          .copyWith(paymentProofPath: 'uid/trx-1/123.jpg');
      expect(PaymentProofCard.appliesTo(cashWithProof), isTrue);
    });
  });

  group('with no proof', () {
    testWidgets('says so and offers to fix it', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(transaction: qris()),
      );

      expect(find.text('BUKTI PEMBAYARAN'), findsOneWidget);
      expect(find.text('Bukti belum dilampirkan'), findsOneWidget);
      expect(find.text('Lampirkan Bukti'), findsOneWidget);
    });

    // The one action here is already a button. A menu offering "ganti" and
    // "hapus" for a photo that does not exist would be two dead entries.
    testWidgets('has no overflow menu to offer', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(transaction: qris()),
      );

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });
  });

  group('with a proof', () {
    const path = 'uid/trx-1/123.jpg';

    testWidgets('names who confirmed it and when', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(
          transaction: qris(
            proofPath: path,
            confirmedAt: DateTime(2026, 7, 31, 14, 22),
          ),
        ),
        providerOverrides: [
          paymentProofUrlProvider(path)
              .overrideWith((ref) async => 'https://example.test/p.jpg'),
        ],
        settle: false,
      );
      await tester.pump();

      expect(find.textContaining('Dikonfirmasi'), findsOneWidget);
      expect(find.textContaining('kasir'), findsOneWidget);
      // The empty state must be gone, or the card invites a second photo over
      // one that already exists.
      expect(find.text('Bukti belum dilampirkan'), findsNothing);
      expect(find.text('Lampirkan Bukti'), findsNothing);
    });

    // The repair path. A proof filed against the wrong sale is worse than no
    // proof at all - it misleads whoever is settling the dispute - so an
    // attached photo has to be swappable and deletable.
    testWidgets('offers a way to change it', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(transaction: qris(proofPath: path)),
        providerOverrides: [
          paymentProofUrlProvider(path)
              .overrideWith((ref) async => 'https://example.test/p.jpg'),
        ],
        settle: false,
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Pilih dari Galeri'), findsOneWidget);
      expect(find.text('Hapus Bukti'), findsOneWidget);
    });

    // Deleting is irreversible and the photo is often the only record of a
    // QRIS payment this app holds. Replacing is not gated the same way - it
    // ends with a proof still attached.
    testWidgets('confirms before deleting', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(transaction: qris(proofPath: path)),
        providerOverrides: [
          paymentProofUrlProvider(path)
              .overrideWith((ref) async => 'https://example.test/p.jpg'),
        ],
        settle: false,
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus Bukti'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Bukti?'), findsOneWidget);
      // The sale survives its evidence, and the dialog has to say so - a shop
      // owner tidying up a blurry photo must not fear voiding the transaction.
      expect(find.textContaining('tidak berubah'), findsOneWidget);

      // Backing out reaches no use case, so nothing here needs the locator.
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Bukti?'), findsNothing);
    });

    // Signing can fail for reasons that say nothing about the photo - no
    // network, an expired session - so the card must not imply the proof is
    // gone.
    testWidgets('offers a retry when the URL cannot be signed', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        PaymentProofCard(transaction: qris(proofPath: path)),
        providerOverrides: [
          paymentProofUrlProvider(path)
              .overrideWith((ref) async => throw Exception('no network')),
        ],
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Gagal memuat - coba lagi'), findsOneWidget);
      expect(find.text('Bukti belum dilampirkan'), findsNothing);
    });
  });
}
