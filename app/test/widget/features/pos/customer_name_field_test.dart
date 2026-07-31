import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/customer_names_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/customer_name_field.dart';

import '../../../helpers/font_helpers.dart';
import '../../../helpers/responsive_helpers.dart';

/// The autocomplete only earns its keep if tapping a suggestion actually fills
/// the field. Everything else about it is decoration.
void main() {
  setUpAll(loadAppFonts);

  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pumpField(
    WidgetTester tester, {
    List<String> names = const ['Bu Sri', 'Pak Ahmad', 'Ibu Rina'],
  }) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      CustomerNameField(controller: controller),
      providerOverrides: [
        customerNamesProvider.overrideWith((ref) async => names),
      ],
    );
  }

  /// Puts the cursor in the field, which is what reveals the suggestions.
  Future<void> focusField(WidgetTester tester) async {
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
  }

  group('suggestions', () {
    testWidgets('stay hidden until the field is used', (tester) async {
      await pumpField(tester);

      expect(find.text('Bu Sri'), findsNothing);
    });

    testWidgets('appear on focus', (tester) async {
      await pumpField(tester);
      await focusField(tester);

      expect(find.text('Bu Sri'), findsOneWidget);
      expect(find.text('Pak Ahmad'), findsOneWidget);
    });

    testWidgets('narrow as the cashier types', (tester) async {
      await pumpField(tester);
      await focusField(tester);

      await tester.enterText(find.byType(TextFormField), 'ibu');
      await tester.pumpAndSettle();

      expect(find.text('Ibu Rina'), findsOneWidget);
      expect(find.text('Pak Ahmad'), findsNothing);
    });
  });

  group('tapping a suggestion', () {
    // The bug this exists for: the suggestion list was mounted only while the
    // field had focus, and a TextField unfocuses on pointer-DOWN outside
    // itself. Pressing a chip therefore tore the chip out of the tree before
    // the pointer came back up, so the tap never completed and the name never
    // arrived.
    testWidgets('fills the field', (tester) async {
      await pumpField(tester);
      await focusField(tester);

      await tester.tap(find.text('Bu Sri'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Bu Sri');
    });

    // HONEST WARNING: none of the tests in this file reproduce the bug that
    // the TapRegion in _SuggestionList fixes. Removing that TapRegion leaves
    // every one of them green. They were checked against the broken widget.
    //
    // The bug was real and only visible in a browser: Flutter's default
    // `onTapOutside` unfocuses a TextField on pointer-DOWN, and the suggestion
    // list is mounted only while the field has focus - so pressing a chip tore
    // it out of the tree before the pointer lifted, and the tap landed on
    // nothing. Fixed by putting the chips in the field's own TapRegion group so
    // the press reads as inside rather than outside.
    //
    // Two reasons the widget tests cannot see it. `flutter test` reports
    // TargetPlatform.android, where that unfocus does nothing (the same trap
    // app/CLAUDE.md documents for ModernHoverBuilder) - and overriding the
    // platform below is *still* not enough, because the TapRegion plumbing
    // behaves differently under the test binding than it does in a real
    // browser. `tester.tap` also fires down and up inside one frame, so no
    // rebuild can happen between them.
    //
    // These two cases are therefore ordinary behavioural coverage, not a
    // regression guard. A real guard needs an integration test on web. Do not
    // read a green run here as proof the chips still work in Chrome.
    for (final platform in {TargetPlatform.macOS, TargetPlatform.windows}) {
      testWidgets('fills the field on $platform, where a tap outside unfocuses',
          (tester) async {
        // Reset inside the body rather than in a tear-down: the binding checks
        // that foundation debug variables are unset at the end of the *body*
        // and fails the test if one is still set. Same pattern as
        // modern_hover_test's asPointerFirst.
        debugDefaultTargetPlatformOverride = platform;
        try {
          await pumpField(tester);
          await focusField(tester);
          expect(find.text('Bu Sri'), findsOneWidget);

          await tester.tap(find.text('Bu Sri'));
          await tester.pumpAndSettle();

          expect(controller.text, 'Bu Sri');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('puts the caret at the end, ready to edit', (tester) async {
      await pumpField(tester);
      await focusField(tester);

      await tester.tap(find.text('Pak Ahmad'));
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, 'Pak Ahmad'.length);
    });

    testWidgets('reports the choice to the caller', (tester) async {
      String? reported;

      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        CustomerNameField(
          controller: controller,
          onChanged: (value) => reported = value,
        ),
        providerOverrides: [
          customerNamesProvider.overrideWith((ref) async => ['Bu Sri']),
        ],
      );
      await focusField(tester);

      await tester.tap(find.text('Bu Sri'));
      await tester.pumpAndSettle();

      expect(reported, 'Bu Sri');
    });

    testWidgets('dismisses the list once a name is chosen', (tester) async {
      await pumpField(tester);
      await focusField(tester);

      await tester.tap(find.text('Bu Sri'));
      await tester.pumpAndSettle();

      // The field now holds the name; leaving three chips underneath it would
      // suggest the choice had not registered.
      expect(find.widgetWithText(TextFormField, 'Bu Sri'), findsOneWidget);
      expect(find.text('Pak Ahmad'), findsNothing);
    });
  });
}
