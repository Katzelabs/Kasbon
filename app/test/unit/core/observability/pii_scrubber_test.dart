import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/observability/pii_scrubber.dart';

/// These are not style assertions. Each case is a shape that a real KASBON
/// crash report can carry off a shop's device, so a failure here means customer
/// names or takings are leaving the phone.
void main() {
  const redacted = PiiScrubber.redacted;

  group('isSensitiveKey', () {
    test('matches snake_case, camelCase and display spellings alike', () {
      for (final spelling in [
        'customer_name',
        'customerName',
        'CustomerName',
        'Customer Name',
        'CUSTOMER_NAME',
      ]) {
        expect(
          PiiScrubber.isSensitiveKey(spelling),
          isTrue,
          reason: '$spelling should be recognised',
        );
      }
    });

    test('leaves keys that carry no customer or money data', () {
      for (final key in ['id', 'created_at', 'status', 'quantity', 'sku']) {
        expect(PiiScrubber.isSensitiveKey(key), isFalse, reason: key);
      }
    });
  });

  group('scrubUrl', () {
    test('drops the PostgREST query string, which is entirely filters', () {
      final scrubbed = PiiScrubber.scrubUrl(
        'https://abc.supabase.co/rest/v1/transactions'
        '?select=*&customer_name=ilike.%2Asri%2A&order=created_at.desc',
      );

      expect(scrubbed, 'https://abc.supabase.co/rest/v1/transactions?$redacted');
      expect(scrubbed, isNot(contains('sri')));
    });

    test('keeps the path, because the table is the useful half', () {
      expect(
        PiiScrubber.scrubUrl('https://abc.supabase.co/rest/v1/transactions'),
        'https://abc.supabase.co/rest/v1/transactions',
      );
    });

    test('redacts everything after a storage bucket', () {
      final scrubbed = PiiScrubber.scrubUrl(
        'https://abc.supabase.co/storage/v1/object/sign/payment-proofs'
        '/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d/2026-08-09/proof.webp'
        '?token=eyJhbGciOiJIUzI1NiJ9',
      );

      expect(scrubbed, contains('payment-proofs'));
      expect(scrubbed, isNot(contains('proof.webp')));
      expect(scrubbed, isNot(contains('2026-08-09')));
      expect(scrubbed, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('redacts a bare uuid segment even outside a bucket', () {
      expect(
        PiiScrubber.scrubUrl(
          'https://abc.supabase.co/rest/v1/profiles'
          '/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
        ),
        'https://abc.supabase.co/rest/v1/profiles/$redacted',
      );
    });

    test('redacts wholesale rather than passing through an unparseable value',
        () {
      // A bare object path is not an absolute URL, but it still names a tenant
      // and a photo, so "not a URL" must not mean "safe".
      expect(
        PiiScrubber.scrubUrl('payment-proofs/some-tenant/proof.webp'),
        redacted,
      );
    });
  });

  group('scrubText', () {
    test('redacts the row quoted by a Postgres constraint violation', () {
      final scrubbed = PiiScrubber.scrubText(
        'duplicate key value violates unique constraint "debts_pkey": '
        'Key (customer_name)=(Sri Wahyuni) already exists.',
      );

      expect(scrubbed, isNot(contains('Sri Wahyuni')));
      expect(scrubbed, contains('(customer_name)=($redacted)'));
      // The part that says what went wrong has to survive, or the report is
      // useless and someone will turn the scrubber off.
      expect(scrubbed, contains('violates unique constraint'));
    });

    test('redacts JSON pairs in an embedded payload', () {
      final scrubbed = PiiScrubber.scrubText(
        'failed to insert {"id":"7","customer_name":"Bu Ani","total_amount":50000}',
      );

      expect(scrubbed, isNot(contains('Bu Ani')));
      expect(scrubbed, isNot(contains('50000')));
      expect(scrubbed, contains('"id":"7"'));
    });

    test('redacts a URL embedded in a message', () {
      final scrubbed = PiiScrubber.scrubText(
        'PostgrestException requesting '
        'https://abc.supabase.co/rest/v1/debts?customer_name=eq.Sri',
      );

      expect(scrubbed, isNot(contains('Sri')));
      expect(scrubbed, contains('/rest/v1/debts'));
    });

    test('leaves a stack-frame-shaped line alone', () {
      const frame =
          '#0      CreateTransaction.call (package:kasbon_pos/features/'
          'transactions/domain/usecases/create_transaction.dart:42:11)';

      expect(PiiScrubber.scrubText(frame), frame);
    });
  });

  group('scrubMap', () {
    test('redacts by key and recurses into nested structures', () {
      final scrubbed = PiiScrubber.scrubMap({
        'transaction_number': 'TRX-20260809-0001',
        'customer_name': 'Pak Budi',
        'items': [
          {'sku': 'A1', 'selling_price': 15000, 'quantity': 2},
        ],
        'shop': {'shop_name': 'Warung Bu Sri', 'id': 'x'},
      });

      expect(scrubbed['transaction_number'], 'TRX-20260809-0001');
      expect(scrubbed['customer_name'], redacted);
      expect(scrubbed['shop']['shop_name'], redacted);
      expect(scrubbed['shop']['id'], 'x');

      final item = (scrubbed['items'] as List).first as Map<String, dynamic>;
      expect(item['selling_price'], redacted);
      expect(item['quantity'], 2, reason: 'quantity is not a price');
      expect(item['sku'], 'A1');
    });

    test('a sensitive key takes its whole subtree, not just its scalars', () {
      final scrubbed = PiiScrubber.scrubMap({
        'notes': {'text': 'bayar minggu depan', 'author': 'Sri'},
      });

      expect(scrubbed['notes'], redacted);
    });

    test('leaves bare numbers alone, so the report stays readable', () {
      final scrubbed = PiiScrubber.scrubMap({'retry_count': 3, 'status': 200});

      expect(scrubbed['retry_count'], 3);
      expect(scrubbed['status'], 200);
    });
  });
}
