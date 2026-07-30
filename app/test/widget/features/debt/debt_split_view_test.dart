import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/features/debt/domain/entities/debt_summary.dart';
import 'package:kasbon_pos/features/debt/domain/usecases/get_unpaid_debts.dart';
import 'package:kasbon_pos/features/debt/presentation/providers/debt_provider.dart';
import 'package:kasbon_pos/features/transactions/domain/usecases/get_transactions.dart';
import 'package:kasbon_pos/features/debt/presentation/screens/debt_list_screen.dart';
import 'package:kasbon_pos/features/transactions/domain/entities/transaction.dart';
import 'package:kasbon_pos/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:kasbon_pos/features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'package:kasbon_pos/features/transactions/presentation/screens/transaction_list_screen.dart';

import '../../../fixtures/mock_data.dart';
import '../../../fixtures/mock_repositories.dart';
import '../../../helpers/responsive_helpers.dart';

/// The debt list in the split view, and the routing wart it was blocked on.
///
/// Debt used to tap through to `/transactions/:id` - a *different branch* - so
/// `/debts` had no detail of its own to dock, and backing out of a debt landed
/// on the transaction history. Both halves of that are pinned here: the tap
/// goes to `/debts/:id`, and both branches are in this router so a regression
/// to the old target would show up as the wrong list underneath.
void main() {
  // The cards' relative timestamps go through DateFormatter, which is built
  // against the Indonesian locale.
  setUpAll(() {
    initializeDateFormatting('id_ID', null);
    registerMocktailFallbackValues();
  });

  final transactionRepository = MockTransactionRepository();

  final debt = MockData.debtTransaction(
    id: 'd1',
    transactionNumber: 'TRX-20260728-0009',
    customerName: 'Budi',
    total: 75000,
  );

  final overrides = <Override>[
    unpaidDebtsProvider.overrideWith(
      (ref) async => UnpaidDebtsResult(debts: [debt]),
    ),
    debtSummaryProvider.overrideWith(
      (ref) async => const DebtSummary(
        totalDebt: 75000,
        customerCount: 1,
        transactionCount: 1,
      ),
    ),
    debtsByCustomerProvider.overrideWith(
      (ref) async => <String, List<Transaction>>{
        'Budi': [debt],
      },
    ),
    transactionDetailProvider.overrideWith((ref, id) async => debt),
    // The other branch, so a tap that regressed to /transactions/:id renders
    // something a finder can catch rather than an error page. The history list
    // pages through its use case now, so it is stubbed at that seam - an empty
    // result still gives the branch an empty state to draw.
    transactionListProvider.overrideWith(
      (ref) => TransactionListNotifier(
        GetTransactions(transactionRepository),
        ref,
      ),
    ),
  ];

  GoRouter buildRouter() {
    Page<void> splitAware(GoRouterState state, Widget child) =>
        SplitDetailPage<void>(
          key: state.pageKey,
          transitionDuration: Duration.zero,
          transitionsBuilder: (_, __, ___, child) => child,
          child: child,
        );

    return GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
      initialLocation: AppRoutes.debts,
      routes: [
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell'),
          builder: (context, state, child) => Scaffold(
            body: ModernBreakpointScope.fromLayout(child: child),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.debts,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: DebtListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => splitAware(
                    state,
                    TransactionDetailScreen(
                      transactionId: state.pathParameters['id']!,
                      basePath: AppRoutes.debts,
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.transactions,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: TransactionListScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => splitAware(
                    state,
                    TransactionDetailScreen(
                      transactionId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpAt(WidgetTester tester, double width) async {
    transactionRepository.stubGetTransactionsSuccess(const []);
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

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('tapping a debt', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('opens /debts/:id at ${ResponsiveWidths.label(width)}',
          (tester) async {
        final router = await pumpAt(tester, width);

        await tester.tap(find.text('TRX-20260728-0009').first);
        await tester.pumpAndSettle();

        expect(locationOf(router), AppRoutes.debtDetailPath('d1'));
        expect(find.byType(TransactionDetailScreen), findsOneWidget);
      });
    }
  });

  // The wart, from the user's end: opening a debt and pressing back used to
  // leave you in the transaction history.
  group('back out of a debt', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('lands on /debts at ${ResponsiveWidths.label(width)}',
          (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.debtDetailPath('d1'));
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue);

        router.pop();
        await tester.pumpAndSettle();

        expect(locationOf(router), AppRoutes.debts);
        expect(find.byType(DebtListScreen), findsOneWidget);
        expect(find.byType(TransactionListScreen), findsNothing);
      });
    }
  });

  group('at a width that splits', () {
    for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
      final label = ResponsiveWidths.label(width);

      testWidgets('$label docks the detail beside the list', (tester) async {
        final router = await pumpAt(tester, width);

        router.go(AppRoutes.debtDetailPath('d1'));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(TransactionDetailScreen)).width,
          lessThan(width / 2),
        );
        // The debt list keeps the room and stays on screen beside it.
        expect(find.text('Budi'), findsWidgets);
      });

      testWidgets('$label shows a placeholder with nothing selected',
          (tester) async {
        await pumpAt(tester, width);

        expect(find.text('Pilih Hutang'), findsOneWidget);
        expect(find.byType(TransactionDetailScreen), findsNothing);
      });
    }
  });

  testWidgets('at compact the detail covers the list', (tester) async {
    final router = await pumpAt(tester, ResponsiveWidths.compact);

    router.go(AppRoutes.debtDetailPath('d1'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(TransactionDetailScreen)).width,
      ResponsiveWidths.compact,
    );
  });
}
