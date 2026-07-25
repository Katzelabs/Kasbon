import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/routes/app_router.dart';

/// These exercise [AppRoutes] only. [AppRouter.router] is deliberately not
/// touched: it is a lazily-initialised static that reaches for
/// `Supabase.instance`, which is not available under `flutter test`.
void main() {
  group('AppRoutes path builders', () {
    test('build the concrete paths screens navigate to', () {
      expect(AppRoutes.productDetailPath('p1'), '/products/p1');
      expect(AppRoutes.productEditPath('p1'), '/products/p1/edit');
      expect(AppRoutes.transactionDetailPath('t1'), '/transactions/t1');
      expect(AppRoutes.receiptPath('t1'), '/transactions/t1/receipt');
      expect(AppRoutes.posSuccessPath('t1'), '/pos/success/t1');
    });

    // The route constants are the patterns GoRouter matches on; the builders
    // are what call sites navigate with. If one is renamed without the other,
    // navigation fails at runtime with no compile error - so pin them together.
    test('agree with the route patterns GoRouter matches on', () {
      final cases = <String, String>{
        AppRoutes.productDetail.replaceAll(':id', 'p1'):
            AppRoutes.productDetailPath('p1'),
        AppRoutes.productEdit.replaceAll(':id', 'p1'):
            AppRoutes.productEditPath('p1'),
        AppRoutes.transactionDetail.replaceAll(':id', 't1'):
            AppRoutes.transactionDetailPath('t1'),
        AppRoutes.receipt.replaceAll(':id', 't1'): AppRoutes.receiptPath('t1'),
        AppRoutes.posSuccess.replaceAll(':transactionId', 't1'):
            AppRoutes.posSuccessPath('t1'),
      };

      cases.forEach((fromPattern, fromBuilder) {
        expect(fromBuilder, fromPattern);
      });
    });

    test('nest detail and edit under the list route', () {
      expect(
        AppRoutes.productDetailPath('p1').startsWith('${AppRoutes.products}/'),
        isTrue,
      );
      expect(
        AppRoutes.productEditPath('p1')
            .startsWith(AppRoutes.productDetailPath('p1')),
        isTrue,
      );
      expect(
        AppRoutes.transactionDetailPath('t1')
            .startsWith('${AppRoutes.transactions}/'),
        isTrue,
      );
      expect(
        AppRoutes.receiptPath('t1')
            .startsWith(AppRoutes.transactionDetailPath('t1')),
        isTrue,
      );
    });

    // The shell highlights a nav item with startsWith, so every sub-route has
    // to sit under its top-level destination for the tab to stay lit.
    test('keep sub-routes under their top-level destination', () {
      for (final sub in [
        AppRoutes.reportsSales,
        AppRoutes.reportsProducts,
        AppRoutes.reportsProfit,
      ]) {
        expect(sub.startsWith('${AppRoutes.reports}/'), isTrue, reason: sub);
      }
      for (final sub in [
        AppRoutes.settingsShopProfile,
        AppRoutes.settingsReceipt,
        AppRoutes.settingsApp,
        AppRoutes.settingsAbout,
        AppRoutes.settingsBackup,
      ]) {
        expect(sub.startsWith('${AppRoutes.settings}/'), isTrue, reason: sub);
      }
    });
  });

  // The bug this guards: go_router's `push` leaves the reported URL on the
  // previous location, so pushing /products/:id showed the detail screen while
  // Chrome's address bar still read /products. `go` is the only one of the two
  // that updates the URL, and every drill-down target is nested in the route
  // table so `go` rebuilds a poppable parent stack.
  test('no screen navigates with context.push', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('context.push(') ||
            lines[i].contains('.pushNamed(')) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use context.go(...) so the URL follows the screen:\n'
          '${offenders.join('\n')}',
    );
  });
}
