import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/transactions/data/models/transaction_model.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';

/// The JSON boundary, where a dropped key is silent.
///
/// Worth its own test because the failure mode here has already happened once:
/// `create_pos_transaction` inserted with an explicit column list, so payment
/// confirmation fields travelled all the way from the dialog to the database
/// and were discarded with no error. Nothing in Dart could have caught that -
/// but a key missing from `toJson` is the same class of bug on this side, and
/// this does catch it.
void main() {
  Map<String, dynamic> rowJson({
    String? proofPath,
    String? confirmedAt,
    String? confirmedBy,
    String? reference,
  }) {
    return {
      'id': 'trx-1',
      'transaction_number': 'TRX-20260731-0001',
      'customer_name': 'Bu Sri',
      'subtotal': 15000,
      'discount_amount': 0,
      'discount_percentage': 0,
      'tax_amount': 0,
      'total': 15000,
      'payment_method': 'qris',
      'payment_status': 'paid',
      'cash_received': null,
      'cash_change': null,
      'notes': 'titip dulu',
      'cashier_name': 'Kasir',
      'transaction_date': '2026-07-31T14:22:00.000Z',
      'debt_paid_at': null,
      'payment_proof_path': proofPath,
      'payment_confirmed_at': confirmedAt,
      'payment_confirmed_by': confirmedBy,
      'payment_reference': reference,
      'created_at': '2026-07-31T14:22:00.000Z',
      'updated_at': '2026-07-31T14:22:00.000Z',
    };
  }

  group('fromJson', () {
    test('reads the payment confirmation columns', () {
      final model = TransactionModel.fromJson(rowJson(
        proofPath: 'uid/trx-1/123.jpg',
        confirmedAt: '2026-07-31T14:22:05.000Z',
        confirmedBy: 'cashier',
        reference: 'RRN-0001',
      ));

      expect(model.paymentProofPath, 'uid/trx-1/123.jpg');
      expect(model.paymentConfirmedAt, DateTime.parse('2026-07-31T14:22:05.000Z'));
      expect(model.paymentConfirmedBy, 'cashier');
      expect(model.paymentReference, 'RRN-0001');
    });

    test('copes with a row that has none of them', () {
      final model = TransactionModel.fromJson(rowJson());

      expect(model.paymentProofPath, isNull);
      expect(model.paymentConfirmedAt, isNull);
      expect(model.paymentConfirmedBy, isNull);
      expect(model.paymentReference, isNull);
    });
  });

  group('toJson', () {
    test('sends the confirmation, which the RPC now reads', () {
      final model = TransactionModel.fromJson(rowJson(
        confirmedAt: '2026-07-31T14:22:05.000Z',
        confirmedBy: 'cashier',
      ));

      final json = model.toJson();

      expect(json['payment_confirmed_by'], 'cashier');
      expect(json['payment_confirmed_at'], isNotNull);
    });

    // Not an oversight. The photo is uploaded after the sale commits - it has
    // to be, since the object path needs the transaction id the insert is about
    // to generate - so there is nothing to send at insert time. It arrives via
    // updateTransaction.
    test('does not send the proof path', () {
      final model = TransactionModel.fromJson(
        rowJson(proofPath: 'uid/trx-1/123.jpg'),
      );

      expect(model.toJson().containsKey('payment_proof_path'), isFalse);
    });
  });

  group('entity round trip', () {
    test('survives model -> entity -> model', () {
      final original = TransactionModel.fromJson(rowJson(
        proofPath: 'uid/trx-1/123.jpg',
        confirmedAt: '2026-07-31T14:22:05.000Z',
        confirmedBy: 'cashier',
        reference: 'RRN-0001',
      ));

      final round = TransactionModel.fromEntity(original.toEntity());

      expect(round.paymentProofPath, original.paymentProofPath);
      expect(round.paymentConfirmedAt, original.paymentConfirmedAt);
      expect(round.paymentConfirmedBy, original.paymentConfirmedBy);
      expect(round.paymentReference, original.paymentReference);
    });

    test('parses the confirmer into the enum', () {
      final entity = TransactionModel.fromJson(
        rowJson(confirmedBy: 'webhook'),
      ).toEntity();

      expect(entity.paymentConfirmedBy, PaymentConfirmedBy.webhook);
    });

    // A value the app does not know about should not become 'cashier' - that
    // would invent a human vouching for the money.
    test('drops an unrecognised confirmer rather than guessing', () {
      final entity = TransactionModel.fromJson(
        rowJson(confirmedBy: 'something_new'),
      ).toEntity();

      expect(entity.paymentConfirmedBy, isNull);
    });
  });
}
