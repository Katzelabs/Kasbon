import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/responsive_utils.dart';

import '../../../helpers/responsive_helpers.dart';

/// Probe that records what the scope reported where it was placed.
class _Probe extends StatelessWidget {
  final void Function(BreakpointData) onBuild;

  const _Probe(this.onBuild);

  @override
  Widget build(BuildContext context) {
    onBuild(context.breakpointData);
    return const SizedBox.shrink();
  }
}

void main() {
  group('measures the container, not the window', () {
    testWidgets('a narrow pane in a wide window reports its own width',
        (tester) async {
      // The bug this whole class exists to prevent: before the scope, a 400dp
      // master pane asked how wide the window was, heard 1600, and rendered a
      // desktop layout into a phone-width column.
      late BreakpointData pane;

      await pumpAtWidth(
        tester,
        1600,
        Row(
          children: [
            SizedBox(
              width: 400,
              child: ModernBreakpointScope.fromLayout(
                isPane: true,
                child: _Probe((d) => pane = d),
              ),
            ),
            const Spacer(),
          ],
        ),
      );

      expect(pane.width, 400);
      expect(pane.breakpoint, Breakpoint.compact);
      expect(pane.isPane, isTrue);
    });

    testWidgets('the same pane still knows how wide the window is',
        (tester) async {
      // Shell chrome nested inside a pane needs the window tier, which is why
      // windowBreakpoint is carried separately rather than recomputed.
      late BreakpointData pane;

      await pumpAtWidth(
        tester,
        1600,
        ModernBreakpointScope.fromLayout(
          child: Row(
            children: [
              SizedBox(
                width: 400,
                child: ModernBreakpointScope.fromLayout(
                  isPane: true,
                  child: _Probe((d) => pane = d),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );

      expect(pane.breakpoint, Breakpoint.compact);
      expect(pane.windowBreakpoint, Breakpoint.large);
    });

    testWidgets('isPane is inherited by nested scopes', (tester) async {
      late BreakpointData inner;

      await pumpAtWidth(
        tester,
        1600,
        SizedBox(
          width: 400,
          child: ModernBreakpointScope.fromLayout(
            isPane: true,
            child: ModernBreakpointScope.fromLayout(
              child: _Probe((d) => inner = d),
            ),
          ),
        ),
      );

      // The inner scope did not declare isPane, but it is inside one, and a
      // widget that needs pane-appropriate chrome must not have to know how
      // many scopes deep it sits.
      expect(inner.isPane, isTrue);
    });
  });

  group('fallback when no scope is installed', () {
    testWidgets('context.breakpoint falls back to the window', (tester) async {
      // Widget tests routinely pump a bare widget. The extension must still
      // answer rather than returning null or throwing.
      late BreakpointData data;

      await pumpAtWidth(tester, 700, _Probe((d) => data = d));

      expect(data.breakpoint, Breakpoint.medium);
      expect(data.width, 700);
      expect(data.isPane, isFalse);
    });
  });

  group('resize', () {
    testWidgets('a scope re-measures when the window is dragged',
        (tester) async {
      // RESP_07 depends on this: computing the split in a go_router
      // pageBuilder would not rebuild on resize, leaving a blank detail pane
      // when Chrome is dragged from 1400 to 700.
      final seen = <Breakpoint>[];

      await pumpAtWidth(
        tester,
        1600,
        ModernBreakpointScope.fromLayout(
          child: _Probe((d) => seen.add(d.breakpoint)),
        ),
      );
      expect(seen.last, Breakpoint.large);

      setViewWidth(tester, 700);
      await tester.pumpAndSettle();

      expect(seen.last, Breakpoint.medium);
    });
  });

  group('responsive<T> cascade', () {
    testWidgets('falls back to the nearest narrower tier supplied',
        (tester) async {
      late BuildContext ctx;

      Future<void> pumpAt(double width) => pumpAtWidth(
            tester,
            width,
            Builder(builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            }),
          );

      // Only compact and expanded supplied, so medium should resolve to
      // compact's value and large to expanded's.
      await pumpAt(375);
      expect(ctx.responsive(compact: 1, expanded: 3), 1);

      await pumpAt(700);
      expect(ctx.responsive(compact: 1, expanded: 3), 1);

      await pumpAt(1100);
      expect(ctx.responsive(compact: 1, expanded: 3), 3);

      await pumpAt(1600);
      expect(ctx.responsive(compact: 1, expanded: 3), 3);
    });
  });

  group('legacy forwarders stay window-based', () {
    testWidgets('a pane does not flip isMobile for its children',
        (tester) async {
      // RESP_03 is a zero-visual-change commit. Had the deprecated getters
      // been repointed at the scope, every screen inside the shell would start
      // measuring the content area instead of the window - and with an 80dp
      // rail, a 900-980dp window would push content under the legacy 900
      // threshold and flip ~24 screens to their phone layout. Screens migrate
      // deliberately in RESP_04 onward instead.
      late bool legacyIsMobile;
      late Breakpoint scoped;

      await pumpAtWidth(
        tester,
        1600,
        SizedBox(
          width: 400,
          child: ModernBreakpointScope.fromLayout(
            isPane: true,
            child: Builder(builder: (context) {
              // ignore: deprecated_member_use_from_same_package
              legacyIsMobile = context.isMobile;
              scoped = context.breakpoint;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      expect(scoped, Breakpoint.compact, reason: 'the pane really is 400dp');
      expect(
        legacyIsMobile,
        isFalse,
        reason: 'the legacy getter still reports the 1600dp window',
      );
    });
  });
}
