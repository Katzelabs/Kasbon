import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
