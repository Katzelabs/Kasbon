import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/platform/app_scroll_behavior.dart';

void main() {
  const behavior = AppScrollBehavior();

  /// Runs [body] with the platform reported as [platform].
  ///
  /// Reset inside the body: the binding checks foundation debug variables are
  /// unset at the end of the test body, before tear-downs run.
  Future<void> asPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('dragDevices', () {
    test('includes mouse and trackpad, which Flutter omits by default', () {
      // Without these, dragging the POS grid with a mouse in Chrome does
      // nothing, while the wheel still works - so the widget looks broken
      // rather than merely un-draggable.
      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
      expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    });

    test('keeps touch and stylus', () {
      expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
      expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));
    });
  });

  group('physics', () {
    testWidgets('clamps off mobile', (tester) async {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        await asPlatform(platform, () async {
          late ScrollPhysics physics;

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  physics = behavior.getScrollPhysics(context);
                  return const SizedBox();
                },
              ),
            ),
          );

          expect(
            physics,
            isA<ClampingScrollPhysics>(),
            reason: '$platform should not bounce',
          );
        });
      }
    });

    testWidgets('leaves native mobile alone', (tester) async {
      await asPlatform(TargetPlatform.iOS, () async {
        late ScrollPhysics physics;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                physics = behavior.getScrollPhysics(context);
                return const SizedBox();
              },
            ),
          ),
        );

        // An iPhone should still bounce - that is the platform's own idiom,
        // and this class exists to stop it leaking everywhere else.
        expect(physics, isA<BouncingScrollPhysics>());
      });
    });
  });

  group('scrollbars', () {
    testWidgets('a vertical list gets one on desktop', (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: behavior,
            home: Scaffold(
              body: ListView(
                children: List.generate(100, (i) => Text('$i')),
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsWidgets);
      });
    });

    testWidgets('a horizontal one does not - it would sit on the last row',
        (tester) async {
      await asPlatform(TargetPlatform.macOS, () async {
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: behavior,
            home: Scaffold(
              body: SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: List.generate(100, (i) => Text('$i')),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsNothing);
      });
    });
  });
}
