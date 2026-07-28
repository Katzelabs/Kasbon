import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/modern/components/layout/modern_app_shell.dart';
import 'package:kasbon_pos/shared/providers/navigation_sidebar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/responsive_helpers.dart';

/// The shell's tier → chrome contract (RESP_04).
///
/// The whole point of these is the `medium` row: 600-899dp used to get the
/// phone build - a four-item bottom bar with POS, Hutang and Laporan simply
/// absent - and now gets the rail with all seven. `compact` is pinned here too,
/// because the epic's rule is that nothing which works today may regress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Every test starts with no stored preference, so the tier defaults apply
    // unless a test says otherwise.
    SharedPreferences.setMockInitialValues({});
  });

  /// Pumps the shell with navigation captured rather than routed.
  ///
  /// Passing `onNavigate` keeps GoRouter out of the test: the shell falls back
  /// to `context.go`, which needs a router above it, and none of these tests
  /// are about routing.
  Future<List<String>> pumpShell(
    WidgetTester tester,
    double width, {
    String currentPath = '/dashboard',
  }) async {
    final navigated = <String>[];

    await pumpScreenAtWidth(
      tester,
      width,
      ModernAppShell(
        currentPath: currentPath,
        onNavigate: navigated.add,
        onFabPressed: () => navigated.add('/pos'),
        child: const SizedBox.expand(),
      ),
    );

    return navigated;
  }

  /// The rail's rendered width, or null when no rail is on screen.
  ///
  /// Measured off the logo tile, which only the rail draws.
  Size? railSize(WidgetTester tester) {
    final logo = find.byIcon(Icons.store_rounded);
    if (logo.evaluate().isEmpty) return null;

    return tester.getSize(
      find.ancestor(of: logo, matching: find.byType(AnimatedContainer)).first,
    );
  }

  group('compact (< 600dp)', () {
    testWidgets('keeps the bottom bar and the notched FAB', (tester) async {
      await pumpShell(tester, ResponsiveWidths.compact);

      expect(find.byType(BottomAppBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(railSize(tester), isNull);
    });

    testWidgets('shows exactly the four bottom-bar destinations',
        (tester) async {
      await pumpShell(tester, ResponsiveWidths.compact);

      for (final item in defaultCompactNavItems) {
        expect(find.text(item.label), findsOneWidget);
      }
      // The three the bar cannot hold stay behind the FAB and the dashboard.
      expect(find.text('Hutang'), findsNothing);
      expect(find.text('Laporan'), findsNothing);
    });
  });

  group('medium (600-899dp)', () {
    testWidgets('drops the bottom bar for a collapsed rail', (tester) async {
      await pumpShell(tester, ResponsiveWidths.medium);

      expect(find.byType(BottomAppBar), findsNothing);
      expect(railSize(tester)?.width, 80.0);
    });

    testWidgets('reaches all seven destinations', (tester) async {
      final navigated = await pumpShell(tester, ResponsiveWidths.medium);

      // Collapsed, the rail is unlabelled glyphs - the tooltip is the name.
      for (final item in defaultRailNavItems) {
        expect(
          find.byTooltip(item.label),
          findsOneWidget,
          reason: '${item.label} is missing from the rail',
        );
      }

      await tester.tap(find.byTooltip('Hutang'));
      expect(navigated, ['/debts']);
    });

    testWidgets('offers no collapse toggle - 280dp would not fit',
        (tester) async {
      await pumpShell(tester, ResponsiveWidths.medium);

      expect(find.byTooltip('Ciutkan menu'), findsNothing);
      expect(find.byTooltip('Lebarkan menu'), findsNothing);
    });
  });

  group('expanded (900-1299dp)', () {
    testWidgets('starts collapsed but can be widened', (tester) async {
      await pumpShell(tester, ResponsiveWidths.expanded);

      expect(railSize(tester)?.width, 80.0);

      await tester.tap(find.byTooltip('Lebarkan menu'));
      await tester.pumpAndSettle();

      expect(railSize(tester)?.width, 280.0);
      expect(find.text('Beranda'), findsOneWidget);
    });
  });

  group('large (>= 1300dp)', () {
    testWidgets('starts expanded, with labels', (tester) async {
      await pumpShell(tester, ResponsiveWidths.large);

      expect(railSize(tester)?.width, 280.0);
      for (final item in defaultRailNavItems) {
        expect(find.text(item.label), findsWidgets);
      }
    });
  });

  group('rail footer', () {
    testWidgets('keeps Kasir one click away, matching the compact FAB',
        (tester) async {
      final navigated = await pumpShell(tester, ResponsiveWidths.medium);

      await tester.tap(find.byTooltip('Buka kasir'));
      expect(navigated, ['/pos']);
    });

    testWidgets('routes the account row to settings', (tester) async {
      // No Supabase in a widget test, so shellAccountProvider yields null and
      // the row falls back to a generic label. It must still navigate.
      final navigated = await pumpShell(tester, ResponsiveWidths.medium);

      await tester.tap(find.byTooltip('Akun'));
      expect(navigated, ['/settings']);
    });
  });

  group('collapse state persistence', () {
    testWidgets('a stored preference beats the tier default', (tester) async {
      SharedPreferences.setMockInitialValues({
        navigationSidebarPrefsKey: false,
      });

      // large defaults to expanded; the stored `false` must win.
      await pumpShell(tester, ResponsiveWidths.large);

      expect(railSize(tester)?.width, 80.0);
    });

    testWidgets('a toggle survives an app restart', (tester) async {
      await pumpShell(tester, ResponsiveWidths.expanded);
      await tester.tap(find.byTooltip('Lebarkan menu'));
      await tester.pumpAndSettle();

      // Re-pumping from scratch is the widget-test stand-in for a cold start:
      // a new ProviderScope, so a new notifier hydrating from disk.
      await pumpShell(tester, ResponsiveWidths.expanded);

      expect(railSize(tester)?.width, 280.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(navigationSidebarPrefsKey), isTrue);
    });
  });

  group('keyboard shortcuts', () {
    /// Presses [key] with [modifier] held.
    Future<void> pressWith(
      WidgetTester tester,
      LogicalKeyboardKey modifier,
      LogicalKeyboardKey key,
    ) async {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+1..7 addresses every destination in order',
        (tester) async {
      final navigated = await pumpShell(tester, ResponsiveWidths.large);

      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
      ];

      for (final digit in digits) {
        await pressWith(tester, LogicalKeyboardKey.controlLeft, digit);
      }

      expect(
        navigated,
        defaultRailNavItems.map((i) => i.routePath).toList(),
      );
    });

    testWidgets('Cmd is bound too, for the Mac keyboard', (tester) async {
      final navigated = await pumpShell(tester, ResponsiveWidths.large);

      await pressWith(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.digit5,
      );

      expect(navigated, ['/debts']);
    });

    testWidgets('still work on compact, where the bar hides three of them',
        (tester) async {
      final navigated = await pumpShell(tester, ResponsiveWidths.compact);

      await pressWith(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.digit6,
      );

      expect(navigated, ['/reports']);
    });

    testWidgets('the shell\'s focus node does not swallow a screen\'s',
        (tester) async {
      // The shortcuts need a focus node inside the shell to sit on the key
      // event chain, and `autofocus` is how it gets there. If that node held
      // focus against a screen, every text field in the app would go dead.
      final navigated = <String>[];

      await pumpScreenAtWidth(
        tester,
        ResponsiveWidths.large,
        ModernAppShell(
          currentPath: '/products',
          onNavigate: navigated.add,
          child: const Material(child: TextField()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'kopi');
      await tester.pump();

      expect(find.text('kopi'), findsOneWidget);

      // ...and the shortcuts still reach the shell from inside the field.
      await pressWith(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.digit1,
      );
      expect(navigated, ['/dashboard']);
    });
  });
}
