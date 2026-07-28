import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/responsive/breakpoint.dart';
import 'package:kasbon_pos/shared/providers/navigation_sidebar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resolveRailExpanded', () {
    test('has no opinion below the rail', () {
      for (final preference in [null, true, false]) {
        expect(resolveRailExpanded(Breakpoint.compact, preference), isFalse);
      }
    });

    test('pins medium collapsed even against an explicit preference', () {
      // 600-899dp cannot spare 280dp for chrome. The preference is remembered,
      // not applied - it takes effect again at expanded.
      expect(resolveRailExpanded(Breakpoint.medium, true), isFalse);
      expect(resolveRailExpanded(Breakpoint.medium, null), isFalse);
    });

    test('defaults expanded to collapsed and large to open', () {
      expect(resolveRailExpanded(Breakpoint.expanded, null), isFalse);
      expect(resolveRailExpanded(Breakpoint.large, null), isTrue);
    });

    test('honours an explicit preference at expanded and large', () {
      expect(resolveRailExpanded(Breakpoint.expanded, true), isTrue);
      expect(resolveRailExpanded(Breakpoint.large, false), isFalse);
    });
  });

  group('NavigationSidebarNotifier', () {
    test('starts unset, so the tier default applies', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationSidebarExpandedProvider), isNull);
    });

    test('hydrates a stored preference', () async {
      SharedPreferences.setMockInitialValues({
        navigationSidebarPrefsKey: true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading the provider constructs the notifier, which then hydrates on a
      // microtask; the SharedPreferences channel resolves a turn later.
      expect(container.read(navigationSidebarExpandedProvider), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(navigationSidebarExpandedProvider), isTrue);
    });

    test('persists an explicit choice', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(navigationSidebarExpandedProvider.notifier)
          .setExpanded(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(navigationSidebarPrefsKey), isTrue);
    });

    test('toggle flips what the tier is currently showing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(navigationSidebarExpandedProvider.notifier);

      // large shows an open rail by default, so the first toggle closes it -
      // `!null` has no answer for that, which is why toggle takes the tier.
      await notifier.toggle(Breakpoint.large);
      expect(container.read(navigationSidebarExpandedProvider), isFalse);

      await notifier.toggle(Breakpoint.large);
      expect(container.read(navigationSidebarExpandedProvider), isTrue);
    });

    test('a toggle during startup is not undone by the disk read', () async {
      // The race this guards: the shell is interactive long before the
      // platform channel answers, so a stored `true` must not overwrite a user
      // who just collapsed the rail.
      SharedPreferences.setMockInitialValues({
        navigationSidebarPrefsKey: true,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(navigationSidebarExpandedProvider.notifier)
          .setExpanded(false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(navigationSidebarExpandedProvider), isFalse);
    });

    test('clear returns the rail to its tier default', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(navigationSidebarExpandedProvider.notifier);
      await notifier.setExpanded(false);
      await notifier.clear();

      expect(container.read(navigationSidebarExpandedProvider), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(navigationSidebarPrefsKey), isFalse);
    });
  });
}
