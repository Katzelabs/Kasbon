import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/responsive/modern_shell_insets.dart';
import 'package:kasbon_pos/core/responsive/modern_breakpoint_scope.dart';

import '../../../helpers/responsive_helpers.dart';

/// The inset must agree with the tier the shell draws a bottom bar for.
///
/// These two move together or nothing works: RESP_04 gave `medium` a rail, so
/// an 834dp iPad has no bar under it. Were the inset still keyed to the legacy
/// 900 threshold, all 25 converted screens would reserve 80px for a bar that is
/// no longer drawn - the "80px dead space" the subtask exists to prevent.
void main() {
  /// Reads [ModernShellInsets.shellBottomInset] at [width].
  Future<double> insetAt(
    WidgetTester tester,
    double width, {
    Widget Function(Widget child)? wrap,
  }) async {
    late double inset;

    Widget probe = Builder(
      builder: (context) {
        inset = context.shellBottomInset;
        return const SizedBox.shrink();
      },
    );
    if (wrap != null) probe = wrap(probe);

    await pumpAtWidth(tester, width, probe);
    return inset;
  }

  testWidgets('reserves the bar height on compact only', (tester) async {
    expect(await insetAt(tester, ResponsiveWidths.compact), 80.0);
  });

  testWidgets('leaves no dead space at medium, where the rail replaced the bar',
      (tester) async {
    expect(await insetAt(tester, ResponsiveWidths.medium), 0.0);
  });

  testWidgets('stays zero at expanded and large', (tester) async {
    expect(await insetAt(tester, ResponsiveWidths.expanded), 0.0);
    expect(await insetAt(tester, ResponsiveWidths.large), 0.0);
  });

  testWidgets('hasShellBottomNav tracks the inset', (tester) async {
    late bool compactHasBar;
    late bool mediumHasBar;

    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      Builder(builder: (context) {
        compactHasBar = context.hasShellBottomNav;
        return const SizedBox.shrink();
      }),
    );
    await pumpAtWidth(
      tester,
      ResponsiveWidths.medium,
      Builder(builder: (context) {
        mediumHasBar = context.hasShellBottomNav;
        return const SizedBox.shrink();
      }),
    );

    expect(compactHasBar, isTrue);
    expect(mediumHasBar, isFalse);
  });

  testWidgets('answers for the window even inside a narrow pane',
      (tester) async {
    // A 300dp pane on a 1600dp desktop still has no bottom bar beneath it,
    // because the shell chose a rail for the *window*. Reading the container
    // tier here would put phantom padding under every narrow pane.
    final inset = await insetAt(
      tester,
      ResponsiveWidths.large,
      wrap: (child) => Row(
        children: [
          SizedBox(
            width: 300,
            child: ModernBreakpointScope.fromLayout(isPane: true, child: child),
          ),
          const Spacer(),
        ],
      ),
    );

    expect(inset, 0.0);
  });
}
