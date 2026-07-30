import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/config/theme/app_dimensions.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';
import '../../../helpers/test_helpers.dart';

/// Pumps a screen with a button that opens [open] when tapped.
Future<void> _pumpOpener(
  WidgetTester tester,
  double width,
  void Function(BuildContext context) open,
) async {
  setViewWidth(tester, width);

  await tester.pumpWidget(createTestableWidgetWithoutScaffold(
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Pumps the compact shell's geometry: a bottom bar painted over a body that
/// extends beneath it, with the sheet opened from a navigator inside that body.
///
/// This is what `ModernAppShell._buildCompactShell` builds, and reproducing it
/// is the point - a sheet opened from a plain `Scaffold` never showed the bug.
Future<void> _pumpShellOpener(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  double bottomInset = 0,
}) async {
  setViewWidth(tester, ResponsiveWidths.compact);
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.padding = FakeViewPadding(
    bottom: bottomInset * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetPadding);

  await tester.pumpWidget(createTestableWidgetWithoutScaffold(
    child: Scaffold(
      extendBody: true,
      body: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SizedBox(
        height: AppDimensions.bottomNavHeight,
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  const marker = Key('sheet-content');
  final content = Container(
    key: marker,
    height: 120,
    constraints: const BoxConstraints(minWidth: 5000),
    child: const Text('isi'),
  );

  group('showAdaptive', () {
    for (final width in [ResponsiveWidths.compact, ResponsiveWidths.medium]) {
      testWidgets('is a bottom sheet at ${ResponsiveWidths.label(width)}',
          (tester) async {
        await _pumpOpener(
          tester,
          width,
          (context) => ModernBottomSheet.showAdaptive<void>(
            context,
            title: 'Pilih',
            child: content,
          ),
        );

        expect(find.byType(ModernBottomSheet), findsOneWidget);

        // Sits at the bottom of the window, which is what makes it a bottom
        // sheet rather than a centred card.
        expect(
          tester.getRect(find.byType(ModernBottomSheet)).bottom,
          closeTo(1200, 1),
        );
      });
    }

    for (final width in [ResponsiveWidths.expanded, ResponsiveWidths.large]) {
      testWidgets(
          'is a right-edge side sheet at ${ResponsiveWidths.label(width)}',
          (tester) async {
        await _pumpOpener(
          tester,
          width,
          (context) => ModernBottomSheet.showAdaptive<void>(
            context,
            title: 'Pilih',
            child: content,
          ),
        );

        expect(find.byType(ModernBottomSheet), findsNothing);

        // Docked to the right edge: the title sits within the right-hand
        // sideSheetWidth of the window, nowhere near the left.
        expect(
          tester.getRect(find.text('Pilih')).left,
          greaterThan(width - ContentLayout.sideSheetWidth - 1),
        );
      });
    }

    testWidgets('caps the modal sheet so it never spans the window',
        (tester) async {
      await _pumpOpener(
        tester,
        ResponsiveWidths.medium,
        (context) => ModernBottomSheet.show<void>(context, child: content),
      );

      expect(
        tester.getSize(find.byType(ModernBottomSheet)).width,
        lessThanOrEqualTo(ModernBottomSheet.maxSheetWidth),
      );
    });
  });

  group('existing call sites keep working', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets(
          'export sheet still returns its result at '
          '${ResponsiveWidths.label(width)}', (tester) async {
        String? result;

        await _pumpOpener(
          tester,
          width,
          (context) async {
            result = await ModernBottomSheet.show<String>(
              context,
              title: 'Ekspor Laporan',
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).pop('pdf'),
                  child: const Text('PDF'),
                ),
              ),
            );
          },
        );

        expect(find.text('Ekspor Laporan'), findsOneWidget);
        await tester.tap(find.text('PDF'));
        await tester.pumpAndSettle();

        expect(result, 'pdf');
      });

      testWidgets(
          'share sheet still returns the tapped index at '
          '${ResponsiveWidths.label(width)}', (tester) async {
        int? selected;

        await _pumpOpener(
          tester,
          width,
          (context) async {
            selected = await ModernBottomSheet.showActions(
              context,
              title: 'Bagikan',
              actions: const [
                ModernBottomSheetAction(label: 'WhatsApp'),
                ModernBottomSheetAction(label: 'Salin Teks'),
              ],
            );
          },
        );

        await tester.tap(find.text('Salin Teks'));
        await tester.pumpAndSettle();

        expect(selected, 1);
      });
    }
  });

  group('bottom inset', () {
    testWidgets('keeps content clear of the shell bottom bar', (tester) async {
      await _pumpShellOpener(
        tester,
        (context) => ModernBottomSheet.show<void>(
          context,
          title: 'Ekspor Laporan',
          child: content,
        ),
      );

      // The sheet itself still runs to the bottom of the window - its surface
      // is meant to sit behind the bar - but the last row of content stops
      // above it. Before this, the bar covered 80dp of tappable tiles.
      expect(tester.getRect(find.byType(ModernBottomSheet)).bottom,
          closeTo(1200, 1));
      expect(
        tester.getRect(find.byKey(marker)).bottom,
        lessThanOrEqualTo(1200 - AppDimensions.bottomNavHeight),
      );
    });

    testWidgets('clears the home indicator with no bar to clear',
        (tester) async {
      // A sheet from a full-screen route outside the shell: no bottom bar, so
      // only the system inset applies. Reading the window width instead - what
      // `shellBottomInset` does - would reserve a phantom 80dp here.
      setViewWidth(tester, ResponsiveWidths.compact);
      tester.view.padding = FakeViewPadding(
        bottom: 34 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);

      await _pumpOpener(
        tester,
        ResponsiveWidths.compact,
        (context) => ModernBottomSheet.show<void>(context, child: content),
      );

      final contentBottom = tester.getRect(find.byKey(marker)).bottom;
      expect(contentBottom, lessThanOrEqualTo(1200 - 34));
      expect(contentBottom, greaterThan(1200 - AppDimensions.bottomNavHeight));
    });

    testWidgets('adds the inset to a caller that asked for zero padding',
        (tester) async {
      await _pumpShellOpener(
        tester,
        (context) => ModernBottomSheet.show<void>(
          context,
          padding: EdgeInsets.zero,
          child: content,
        ),
      );

      // The date range picker passes EdgeInsets.zero because its child draws
      // its own padding - not because it may run under the navigation bar.
      expect(
        tester.getRect(find.byKey(marker)).bottom,
        closeTo(1200 - AppDimensions.bottomNavHeight, 1),
      );
    });
  });

  group('showAdaptiveDraggable', () {
    testWidgets('gives its child a bounded height, so Expanded works',
        (tester) async {
      // The reason this method exists: showAdaptive wraps in a scroll view, and
      // a cart list with a pinned total under it cannot expand into that.
      await _pumpOpener(
        tester,
        ResponsiveWidths.compact,
        (context) => ModernBottomSheet.showAdaptiveDraggable<void>(
          context,
          builder: (context, controller) => Column(
            children: [
              Expanded(
                child: ListView(
                  controller: controller,
                  children: const [Text('baris')],
                ),
              ),
              const Text('TOTAL'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('TOTAL'), findsOneWidget);
    });

    testWidgets('passes no controller on the side-sheet path', (tester) async {
      ScrollController? seen;
      var built = false;

      await _pumpOpener(
        tester,
        ResponsiveWidths.large,
        (context) => ModernBottomSheet.showAdaptiveDraggable<void>(
          context,
          builder: (context, controller) {
            seen = controller;
            built = true;
            return const Text('keranjang');
          },
        ),
      );

      expect(built, isTrue);
      expect(seen, isNull);
      expect(find.text('keranjang'), findsOneWidget);
    });
  });
}
