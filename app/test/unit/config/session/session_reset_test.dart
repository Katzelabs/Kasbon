import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/session/session_reset.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/cart_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/pos_search_provider.dart';
import 'package:kasbon_pos/features/reports/presentation/providers/analytics_provider.dart';
import 'package:kasbon_pos/features/reports/domain/entities/sales_trend_point.dart';
import 'package:kasbon_pos/shared/providers/user_provider.dart';

import '../../../fixtures/mock_data.dart';

/// Stands in for the Supabase-backed account id, so a test can switch accounts
/// without a session.
final _signedInId = StateProvider<String?>((ref) => 'user-a');

List<Override> _overrides() => [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_signedInId)),
    ];

void main() {
  group('resetSessionState', () {
    test('empties a cart left behind by the previous account', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(
            MockData.createProduct(),
          );
      expect(container.read(cartProvider), isNotEmpty);

      resetSessionState(container);

      expect(container.read(cartProvider), isEmpty);
    });

    test('clears the POS search box and category filter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(posSearchQueryProvider.notifier).state = 'kopi';
      container.read(posCategoryFilterProvider.notifier).state = 'cat-1';

      resetSessionState(container);

      expect(container.read(posSearchQueryProvider), '');
      expect(container.read(posCategoryFilterProvider), isNull);
    });

    test('clears report scope', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(trendGranularityProvider.notifier).state =
          TrendGranularity.month;

      resetSessionState(container);

      expect(container.read(trendGranularityProvider), isNull);
    });
  });

  group('SessionGate', () {
    testWidgets('resets session state when the account changes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: const SessionGate(child: SizedBox()),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionGate)),
      );
      container.read(cartProvider.notifier).addProduct(
            MockData.createProduct(),
          );

      container.read(_signedInId.notifier).state = 'user-b';
      await tester.pump();

      expect(container.read(cartProvider), isEmpty);
    });

    testWidgets('resets on sign-out', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: const SessionGate(child: SizedBox()),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionGate)),
      );
      container.read(posSearchQueryProvider.notifier).state = 'kopi';

      container.read(_signedInId.notifier).state = null;
      await tester.pump();

      expect(container.read(posSearchQueryProvider), '');
    });

    testWidgets('leaves the cart alone when the same account re-emits',
        (tester) async {
      // A token refresh pushes an auth event every hour, and one of those can
      // land mid-sale. It must not empty the cart, which is why the gate
      // listens to the account id rather than to the auth stream.
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: const SessionGate(child: SizedBox()),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionGate)),
      );
      container.read(cartProvider.notifier).addProduct(
            MockData.createProduct(),
          );

      container.read(_signedInId.notifier).state = 'user-a';
      await tester.pump();

      expect(container.read(cartProvider), isNotEmpty);
    });
  });
}
