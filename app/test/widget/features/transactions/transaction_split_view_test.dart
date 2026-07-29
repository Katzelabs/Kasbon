import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/features/receipt/presentation/providers/receipt_provider.dart';
import 'package:kasbon_pos/features/receipt/presentation/screens/receipt_screen.dart';
import 'package:kasbon_pos/features/receipt/domain/entities/shop_settings.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:kasbon_pos/features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'package:kasbon_pos/features/transactions/presentation/screens/transaction_list_screen.dart';
import 'package:kasbon_pos/config/theme/app_dimensions.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// The transactions list in the split view, and the detail screen doing double
/// duty as its pane.
///
/// [AppRouter.router] cannot be pumped - it is a lazily initialised static that
/// reaches for `Supabase.instance` - so this rebuilds the transactions branch
/// with the same shape and the same pages: the list in a
/// [MasterDetailScaffold], `:id` behind a [SplitDetailPage], `receipt` behind
/// an ordinary opaque one.
void main() {
  // The date headers and the detail's timestamps go through DateFormatter,
  // which is built against the Indonesian locale.
  setUpAll(() => initializeDateFormatting('id_ID', null));

  final t1 = MockData.createTransaction(
    id: 't1',
    transactionNumber: 'TRX-20260728-0001',
    total: 25000,
  );
  final t2 = MockData.createTransaction(
    id: 't2',
    transactionNumber: 'TRX-20260728-0002',
    total: 40000,
  );

  final overrides = <Override>[
    groupedTransactionsProvider.overrideWith((ref) async {
      final day = DateTime(
        t1.transactionDate.year,
        t1.transactionDate.month,
        t1.transactionDate.day,
      );
      return <DateTime, List<Transaction>>{
        day: [t1, t2],
      };
    }),
    transactionDetailProvider.overrideWith(
      (ref, id) async => id == 't2' ? t2 : t1,
    ),
    receiptProvider.overrideWith(
      (ref, id) async => ReceiptData(
        transaction: t1,
        shopSettings: ShopSettings.defaultSettings(),
        receiptText: 'STRUK',
      ),
    ),
  ];

  GoRouter buildRouter() {
    return GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
      initialLocation: AppRoutes.transactions,
      routes: [
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell'),
          // Mirrors ModernAppShell: the scope both panes read sits above the
          // inner navigator, so a resize reaches every page in it.
          builder: (context, state, child) => Scaffold(
            body: ModernBreakpointScope.fromLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.transactions,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: TransactionListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => SplitDetailPage<void>(
                    key: state.pageKey,
                    transitionDuration: Duration.zero,
                    transitionsBuilder: (_, __, ___, child) => child,
                    child: TransactionDetailScreen(
                      transactionId: state.pathParameters['id']!,
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'receipt',
                      pageBuilder: (context, state) => MaterialPage(
                        child: ReceiptScreen(
                          transactionId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpAt(WidgetTester tester, double width) async {
    setViewWidth(tester, width);
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// The pane and the full-screen route render the same widget, so a type
  /// finder cannot tell them apart. Its width can: a pane is the narrow half.
  double detailWidth(WidgetTester tester) =>
      tester.getRect(find.byType(TransactionDetailScreen)).width;

  group('at a width that splits', () {
    for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
      final label = ResponsiveWidths.label(width);

      testWidgets('$label docks the detail beside the list', (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();

        expect(find.byType(TransactionDetailScreen), findsOneWidget);
        expect(detailWidth(tester), lessThan(width / 2));
        // The list is not covered - that is the whole point.
        expect(find.text('TRX-20260728-0002'), findsWidgets);
      });

      testWidgets('$label shows a placeholder with nothing selected',
          (tester) async {
        await pumpAt(tester, width);

        expect(find.text('Pilih Transaksi'), findsOneWidget);
        expect(find.byType(TransactionDetailScreen), findsNothing);
      });

      testWidgets('$label swaps the pane when another row is opened',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();
        expect(find.text('TRX-20260728-0001'), findsWidgets);

        router.go(AppRoutes.transactionDetailPath('t2'));
        await tester.pumpAndSettle();

        // The pane's own header carries the open transaction's number.
        expect(find.text('TRX-20260728-0002'), findsWidgets);
      });

      // The regression: a Scaffold paints `scaffoldBackgroundColor` by
      // default, so docking this screen repainted the window's grey canvas
      // over the panel's white surface *and* over the rule that separates the
      // two. Selecting a row made the panel vanish into the list.
      testWidgets('$label lets the panel surface through, canvas and all',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(TransactionDetailScreen),
            matching: find.byType(Scaffold),
          ),
        );
        expect(scaffold.backgroundColor, Colors.transparent);
      });

      // A short transaction used to float in the middle of a tall pane, with a
      // band of empty surface above the first card - ModernContentColumn was
      // centring on both axes.
      testWidgets('$label starts the detail at the top of the pane',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();

        final body = tester.getRect(find.byType(TransactionDetailScreen));
        // Scoped to the pane: the list beside it is built from ModernCards
        // too, and an unscoped finder lands on the first row of the master.
        final firstCard = tester.getRect(
          find
              .descendant(
                of: find.byType(TransactionDetailScreen),
                matching: find.byType(ModernCard),
              )
              .first,
        );

        // Header bar plus the column's own top padding, and nothing else.
        expect(
          firstCard.top - body.top,
          lessThan(kToolbarHeight + AppDimensions.spacing32),
        );
      });

      // A pane has nothing to go back to and no business carrying the account
      // menu - that belongs to the window, once.
      testWidgets('$label gives the pane close chrome, not back chrome',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
      });
    }
  });

  testWidgets('at compact the detail is a full page with a back button',
      (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.compact);

    router.go(AppRoutes.transactionDetailPath('t1'));
    await tester.pumpAndSettle();

    expect(detailWidth(tester), ResponsiveWidths.compact);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    // As a screen it *is* on the window's canvas, so it keeps the theme's
    // background rather than showing whatever is behind the non-opaque page.
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(TransactionDetailScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, isNull);
  });

  // The receipt is a print preview already clamped to 400px, so a pane would
  // show the same paper strip with more grey around it. It stays a screen at
  // every tier - which means an opaque page, over both panes.
  group('the receipt stays full-screen', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('at ${ResponsiveWidths.label(width)}', (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.receiptPath('t1'));
        await tester.pumpAndSettle();

        expect(find.byType(ReceiptScreen), findsOneWidget);
        expect(tester.getRect(find.byType(ReceiptScreen)).width, width);
      });
    }

    testWidgets('and returns to the transaction it was printed from',
        (tester) async {
      final router = await pumpAt(tester, ResponsiveWidths.large);

      router.go(AppRoutes.receiptPath('t1'));
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        AppRoutes.transactionDetailPath('t1'),
      );
      // ...and back into the pane, not onto a page of its own.
      expect(detailWidth(tester), lessThan(ResponsiveWidths.large / 2));
    });
  });

  group('back', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('lands on the list at ${ResponsiveWidths.label(width)}',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.transactionDetailPath('t1'));
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);

        router.pop();
        await tester.pumpAndSettle();

        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          AppRoutes.transactions,
        );
        expect(find.byType(TransactionDetailScreen), findsNothing);
      });
    }
  });
}
