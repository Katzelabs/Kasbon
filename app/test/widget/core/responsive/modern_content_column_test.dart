import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';

import '../../../helpers/responsive_helpers.dart';

void main() {
  group('clamping', () {
    testWidgets('clamps to the chosen width on a wide window', (tester) async {
      await pumpAtWidth(
        tester,
        1600,
        const ModernContentColumn.form(
          horizontalPadding: 0,
          child: SizedBox(height: 10, child: Placeholder()),
        ),
      );

      final box = tester.getSize(find.byType(Placeholder));
      expect(box.width, ContentWidth.form.maxWidth);
    });

    testWidgets('does not stretch a narrow window', (tester) async {
      // The clamp is a ceiling, not a target: on a phone the content should
      // still fill the screen.
      await pumpAtWidth(
        tester,
        375,
        const ModernContentColumn.form(
          horizontalPadding: 0,
          child: SizedBox(height: 10, child: Placeholder()),
        ),
      );

      expect(tester.getSize(find.byType(Placeholder)).width, 375);
    });

    testWidgets('ContentWidth.full leaves the width alone', (tester) async {
      await pumpAtWidth(
        tester,
        2560,
        const ModernContentColumn(
          width: ContentWidth.full,
          horizontalPadding: 0,
          child: SizedBox(height: 10, child: Placeholder()),
        ),
      );

      expect(tester.getSize(find.byType(Placeholder)).width, 2560);
    });

    testWidgets('subtracts horizontal padding from the clamped width',
        (tester) async {
      await pumpAtWidth(
        tester,
        1600,
        const ModernContentColumn.form(
          horizontalPadding: 24,
          child: SizedBox(height: 10, child: Placeholder()),
        ),
      );

      expect(
        tester.getSize(find.byType(Placeholder)).width,
        ContentWidth.form.maxWidth - 48,
      );
    });
  });

  group('re-scoping', () {
    testWidgets('children see the column width, not the window',
        (tester) async {
      // The subtle failure this prevents: a 560dp form centred in a 1600dp
      // window whose children still believe they have 1600dp, and helpfully
      // lay out in three columns inside 560.
      late BreakpointData inner;

      await pumpAtWidth(
        tester,
        1600,
        ModernContentColumn.form(
          horizontalPadding: 0,
          child: Builder(builder: (context) {
            inner = context.breakpointData;
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(inner.width, ContentWidth.form.maxWidth);
      expect(inner.breakpoint, Breakpoint.compact);
    });

    testWidgets('the window tier is still reachable for shell chrome',
        (tester) async {
      late BreakpointData inner;

      await pumpAtWidth(
        tester,
        1600,
        ModernBreakpointScope.fromLayout(
          inheritWindow: false,
          child: ModernContentColumn.form(
            horizontalPadding: 0,
            child: Builder(builder: (context) {
              inner = context.breakpointData;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(inner.breakpoint, Breakpoint.compact);
      expect(inner.windowBreakpoint, Breakpoint.large);
    });
  });

  group('SliverContentColumn', () {
    testWidgets('clamps a sliver on a wide window', (tester) async {
      await pumpAtWidth(
        tester,
        1600,
        CustomScrollView(
          slivers: [
            SliverContentColumn(
              horizontalPadding: 0,
              sliver: SliverToBoxAdapter(
                child: Container(height: 40, color: const Color(0xFF000000)),
              ),
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.byType(Container)).width,
        ContentWidth.standard.maxWidth,
      );
    });

    testWidgets('leaves a narrow window alone', (tester) async {
      await pumpAtWidth(
        tester,
        375,
        CustomScrollView(
          slivers: [
            SliverContentColumn(
              horizontalPadding: 0,
              sliver: SliverToBoxAdapter(
                child: Container(height: 40, color: const Color(0xFF000000)),
              ),
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byType(Container)).width, 375);
    });
  });
}
