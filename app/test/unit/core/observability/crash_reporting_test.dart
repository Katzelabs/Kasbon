import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/observability/crash_reporting.dart';
import 'package:kasbon_pos/core/observability/pii_scrubber.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// `PiiScrubber` is tested on its own. This covers the wiring: that every field
/// of an event which can carry a value is actually routed through it. A scrubber
/// that is never called on `exceptions` is no scrubber at all.
void main() {
  const redacted = PiiScrubber.redacted;

  group('scrubEvent', () {
    test('strips the user down to the id, dropping email and ip', () {
      final scrubbed = scrubEvent(
        SentryEvent(
          user: SentryUser(
            id: 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
            email: 'bu.sri@example.com',
            username: 'Bu Sri',
            ipAddress: '103.28.14.9',
          ),
        ),
        Hint(),
      );

      expect(scrubbed!.user!.id, 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d');
      expect(scrubbed.user!.email, isNull);
      expect(scrubbed.user!.username, isNull);
      expect(scrubbed.user!.ipAddress, isNull);
    });

    test('replaces a user that has no id, rather than keeping it', () {
      // The trap: `copyWith` reads null as "unchanged", so a scrubber that
      // signalled removal by returning null would keep this user's email. And
      // `SentryUser` asserts one identifying field is set, so an empty
      // replacement throws — which sends the event unscrubbed.
      final scrubbed = scrubEvent(
        SentryEvent(
          user: SentryUser(
            email: 'bu.sri@example.com',
            ipAddress: '103.28.14.9',
          ),
        ),
        Hint(),
      );

      expect(scrubbed, isNotNull);
      expect(scrubbed!.user!.email, isNull);
      expect(scrubbed.user!.ipAddress, isNull);
      expect(scrubbed.user!.id, redacted);
    });

    test('scrubs the exception message', () {
      final scrubbed = scrubEvent(
        SentryEvent(
          exceptions: const [
            SentryException(
              type: 'PostgrestException',
              value: 'Key (customer_name)=(Sri Wahyuni) already exists.',
            ),
          ],
        ),
        Hint(),
      );

      final value = scrubbed!.exceptions!.single.value!;
      expect(value, isNot(contains('Sri Wahyuni')));
      expect(scrubbed.exceptions!.single.type, 'PostgrestException',
          reason: 'the exception class is what groups the issue');
    });

    test('scrubs the request url and drops the query string', () {
      final scrubbed = scrubEvent(
        SentryEvent(
          request: SentryRequest(
            url: 'https://abc.supabase.co/rest/v1/debts',
            method: 'GET',
            queryString: 'customer_name=ilike.%2Asri%2A',
          ),
        ),
        Hint(),
      );

      expect(scrubbed!.request!.queryString, redacted);
      expect(scrubbed.request!.method, 'GET');
    });

    test('scrubs breadcrumbs carried on the event', () {
      final scrubbed = scrubEvent(
        SentryEvent(
          breadcrumbs: [
            Breadcrumb(
              message: 'GET https://abc.supabase.co/rest/v1/debts'
                  '?customer_name=eq.Sri',
              category: 'http',
              data: const {'total_amount': 50000, 'status_code': 200},
            ),
          ],
        ),
        Hint(),
      );

      final crumb = scrubbed!.breadcrumbs!.single;
      expect(crumb.message, isNot(contains('Sri')));
      expect(crumb.data!['total_amount'], redacted);
      expect(crumb.data!['status_code'], 200);
      expect(crumb.category, 'http');
    });

    test('leaves an event with nothing sensitive untouched', () {
      final scrubbed = scrubEvent(
        SentryEvent(
          exceptions: const [
            SentryException(type: 'StateError', value: 'cart is empty'),
          ],
        ),
        Hint(),
      );

      expect(scrubbed!.exceptions!.single.value, 'cart is empty');
    });
  });

  group('scrubBreadcrumb', () {
    test('redacts the query string of a navigation or http crumb', () {
      final scrubbed = scrubBreadcrumb(
        Breadcrumb(
          message: 'https://abc.supabase.co/rest/v1/transactions'
              '?customer_name=eq.Budi',
        ),
        Hint(),
      );

      expect(scrubbed!.message, isNot(contains('Budi')));
      expect(scrubbed.message, contains('/rest/v1/transactions'));
    });

    test('passes null through rather than throwing', () {
      expect(scrubBreadcrumb(null, Hint()), isNull);
    });
  });
}
