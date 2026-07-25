import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';

import '../../../../../fixtures/mock_data.dart';

void main() {
  group('Transaction', () {
    group('totalProfit', () {
      test('calculates total profit from all items', () {
        final transaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(
              costPrice: 10000,
              sellingPrice: 15000,
              quantity: 2,
            ),
            MockData.createTransactionItem(
              id: 'item-2',
              productId: 'prod-2',
              costPrice: 5000,
              sellingPrice: 8000,
              quantity: 3,
            ),
          ],
        );
        // Item 1: (15000 - 10000) * 2 = 10000
        // Item 2: (8000 - 5000) * 3 = 9000
        // Total: 19000
        expect(transaction.totalProfit, 19000);
      });

      test('returns zero for empty items', () {
        final transaction = MockData.createTransaction(items: []);
        expect(transaction.totalProfit, 0);
      });

      test('handles negative profit (loss)', () {
        final transaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(
              costPrice: 15000,
              sellingPrice: 10000,
              quantity: 2,
            ),
          ],
        );
        // (10000 - 15000) * 2 = -10000
        expect(transaction.totalProfit, -10000);
      });
    });

    group('totalQuantity', () {
      test('sums quantity from all items', () {
        final transaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(quantity: 2),
            MockData.createTransactionItem(
              id: 'item-2',
              productId: 'prod-2',
              quantity: 3,
            ),
            MockData.createTransactionItem(
              id: 'item-3',
              productId: 'prod-3',
              quantity: 5,
            ),
          ],
        );
        expect(transaction.totalQuantity, 10);
      });

      test('returns zero for empty items', () {
        final transaction = MockData.createTransaction(items: []);
        expect(transaction.totalQuantity, 0);
      });
    });

    group('uniqueItemCount', () {
      test('returns number of unique products', () {
        final transaction = MockData.createTransaction(
          items: [
            MockData.createTransactionItem(id: 'item-1'),
            MockData.createTransactionItem(id: 'item-2', productId: 'prod-2'),
            MockData.createTransactionItem(id: 'item-3', productId: 'prod-3'),
          ],
        );
        expect(transaction.uniqueItemCount, 3);
      });

      test('returns zero for empty items', () {
        final transaction = MockData.createTransaction(items: []);
        expect(transaction.uniqueItemCount, 0);
      });
    });

    group('isPaid', () {
      test('returns true for paid status', () {
        final transaction = MockData.createTransaction(
          paymentStatus: PaymentStatus.paid,
        );
        expect(transaction.isPaid, true);
      });

      test('returns false for debt status', () {
        final transaction = MockData.debtTransaction();
        expect(transaction.isPaid, false);
      });
    });

    group('isDebt', () {
      test('returns true for debt status', () {
        final transaction = MockData.debtTransaction();
        expect(transaction.isDebt, true);
      });

      test('returns false for paid status', () {
        final transaction = MockData.createTransaction(
          paymentStatus: PaymentStatus.paid,
        );
        expect(transaction.isDebt, false);
      });
    });

    group('isDebtSettled', () {
      test('returns true when debt is settled', () {
        final now = DateTime.now();
        final transaction = MockData.debtTransaction(
          debtPaidAt: now,
        );
        expect(transaction.isDebtSettled, true);
      });

      test('returns false when debt is not settled', () {
        final transaction = MockData.debtTransaction(debtPaidAt: null);
        expect(transaction.isDebtSettled, false);
      });

      test('returns false for non-debt transaction', () {
        final transaction = MockData.createTransaction(
          paymentStatus: PaymentStatus.paid,
        );
        expect(transaction.isDebtSettled, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated total', () {
        final original = MockData.createTransaction(total: 50000);
        final updated = original.copyWith(total: 75000);

        expect(updated.total, 75000);
        expect(updated.id, original.id);
      });

      test('creates copy with updated payment status', () {
        final original = MockData.debtTransaction();
        final updated = original.copyWith(
          paymentStatus: PaymentStatus.paid,
          debtPaidAt: DateTime.now(),
        );

        expect(updated.paymentStatus, PaymentStatus.paid);
        expect(updated.debtPaidAt, isNotNull);
      });

      test('preserves original values when not updated', () {
        final original = MockData.createTransaction(
          transactionNumber: 'TRX-123',
          total: 50000,
        );
        final updated = original.copyWith(total: 75000);

        expect(updated.transactionNumber, 'TRX-123');
        expect(updated.paymentMethod, original.paymentMethod);
      });

      test('creates new instance (immutable)', () {
        final original = MockData.createTransaction(total: 50000);
        final updated = original.copyWith(total: 75000);

        expect(identical(original, updated), false);
        expect(original.total, 50000);
      });
    });

    group('equality', () {
      test('transactions with same id are equal', () {
        final trx1 = MockData.createTransaction(
          id: 'trx-1',
          transactionNumber: 'TRX-001',
        );
        final trx2 = MockData.createTransaction(
          id: 'trx-1',
          transactionNumber: 'TRX-001',
        );
        expect(trx1, equals(trx2));
      });

      test('transactions with different id are not equal', () {
        final trx1 = MockData.createTransaction(id: 'trx-1');
        final trx2 = MockData.createTransaction(id: 'trx-2');
        expect(trx1, isNot(equals(trx2)));
      });
    });

    group('toString', () {
      test('returns meaningful string representation', () {
        final transaction = MockData.createTransaction(
          id: 'trx-1',
          transactionNumber: 'TRX-20260126-0001',
          total: 50000,
          paymentStatus: PaymentStatus.paid,
        );
        final str = transaction.toString();

        expect(str, contains('trx-1'));
        expect(str, contains('TRX-20260126-0001'));
        expect(str, contains('50000'));
        expect(str, contains('Lunas'));
      });
    });
  });

  group('PaymentMethod', () {
    group('label', () {
      test('cash returns Tunai', () {
        expect(PaymentMethod.cash.label, 'Tunai');
      });

      test('transfer returns Transfer', () {
        expect(PaymentMethod.transfer.label, 'Transfer');
      });

      test('qris returns QRIS', () {
        expect(PaymentMethod.qris.label, 'QRIS');
      });

      test('debt returns Hutang', () {
        expect(PaymentMethod.debt.label, 'Hutang');
      });
    });

    group('fromString', () {
      test('parses cash correctly', () {
        expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      });

      test('parses transfer correctly', () {
        expect(PaymentMethod.fromString('transfer'), PaymentMethod.transfer);
      });

      test('parses qris correctly', () {
        expect(PaymentMethod.fromString('qris'), PaymentMethod.qris);
      });

      test('parses debt correctly', () {
        expect(PaymentMethod.fromString('debt'), PaymentMethod.debt);
      });

      test('handles uppercase input', () {
        expect(PaymentMethod.fromString('CASH'), PaymentMethod.cash);
      });

      test('handles mixed case input', () {
        expect(PaymentMethod.fromString('Cash'), PaymentMethod.cash);
      });

      test('defaults to cash for unknown value', () {
        expect(PaymentMethod.fromString('unknown'), PaymentMethod.cash);
      });
    });
  });

  group('PaymentStatus', () {
    group('label', () {
      test('paid returns Lunas', () {
        expect(PaymentStatus.paid.label, 'Lunas');
      });

      test('debt returns Hutang', () {
        expect(PaymentStatus.debt.label, 'Hutang');
      });
    });

    group('fromString', () {
      test('parses paid correctly', () {
        expect(PaymentStatus.fromString('paid'), PaymentStatus.paid);
      });

      test('parses debt correctly', () {
        expect(PaymentStatus.fromString('debt'), PaymentStatus.debt);
      });

      test('handles uppercase input', () {
        expect(PaymentStatus.fromString('PAID'), PaymentStatus.paid);
      });

      test('defaults to paid for unknown value', () {
        expect(PaymentStatus.fromString('unknown'), PaymentStatus.paid);
      });
    });
  });
}
