import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/onboarding/domain/entities/business_type.dart';
import 'package:kasbon_pos/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:kasbon_pos/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:kasbon_pos/features/onboarding/presentation/widgets/onboarding_progress.dart';
import 'package:kasbon_pos/shared/modern/modern.dart';

import '../../../helpers/responsive_helpers.dart';
import 'onboarding_fixtures.dart';

/// The wizard's gate and its category suggestions.
///
/// Step 1 is the only blocking screen in the app, and what it blocks on is the
/// `shop_settings` row: without it `name` is NOT NULL and unset, receipts print
/// an unnamed shop, and nothing else in the app creates it.
void main() {
  Future<void> pumpWizard(
    WidgetTester tester, {
    double width = ResponsiveWidths.compact,
    List<Override>? overrides,
  }) =>
      pumpScreenAtWidth(
        tester,
        width,
        const OnboardingScreen(),
        providerOverrides: overrides ?? onboardingOverrides(),
        settle: false,
      );

  OnboardingNotifier notifierOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)))
          .read(onboardingProvider.notifier);

  OnboardingState stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)))
          .read(onboardingProvider);

  group('step 1 blocks', () {
    testWidgets('Lanjut is dead until both questions are answered',
        (tester) async {
      await pumpWizard(tester);

      ModernButton lanjut() => tester.widget<ModernButton>(
            find.widgetWithText(ModernButton, 'Lanjut'),
          );

      expect(lanjut().onPressed, isNull);

      // A name alone is not enough - the trade is what seeds the categories.
      await tester.enterText(find.byType(TextField).first, 'Warung Bu Sri');
      await tester.pump();
      expect(lanjut().onPressed, isNull);

      await tester.tap(find.text('Kedai Kopi'));
      await tester.pump();
      expect(lanjut().onPressed, isNotNull);
    });

    testWidgets('a one-character shop name is not a shop name', (tester) async {
      await pumpWizard(tester);

      await tester.enterText(find.byType(TextField).first, 'W');
      await tester.tap(find.text('Warung Makan'));
      await tester.pump();

      expect(
        tester
            .widget<ModernButton>(find.widgetWithText(ModernButton, 'Lanjut'))
            .onPressed,
        isNull,
      );
    });
  });

  group('category suggestions', () {
    testWidgets('picking a trade pre-ticks that trade\'s categories',
        (tester) async {
      await pumpWizard(tester);

      notifierOf(tester).setBusinessType(BusinessType.kedaiKopi);
      await tester.pump();

      expect(
        stateOf(tester).selectedCategories,
        BusinessType.kedaiKopi.starterCategories.toSet(),
      );
    });

    testWidgets('switching trades keeps what the user typed themselves',
        (tester) async {
      await pumpWizard(tester);

      final notifier = notifierOf(tester);
      notifier.setBusinessType(BusinessType.warungMakan);
      notifier.addCustomCategory('Gorengan');
      await tester.pump();

      notifier.setBusinessType(BusinessType.kedaiKopi);
      await tester.pump();

      final selected = stateOf(tester).selectedCategories;
      // The new trade's starters arrive...
      expect(selected, containsAll(BusinessType.kedaiKopi.starterCategories));
      // ...and "Gorengan" is not collateral damage.
      expect(selected, contains('Gorengan'));
      // But Warung Makan's own suggestions are dropped. "Minuman", not
      // "Snack": Snack is a starter for both trades, so it proves nothing.
      expect(selected, isNot(contains('Minuman')));
    });

    testWidgets('a category can be unticked', (tester) async {
      await pumpWizard(tester);

      final notifier = notifierOf(tester);
      notifier.setBusinessType(BusinessType.jasa);
      await tester.pump();
      expect(stateOf(tester).selectedCategories, contains('Layanan'));

      notifier.toggleCategory('Layanan');
      await tester.pump();
      expect(stateOf(tester).selectedCategories, isNot(contains('Layanan')));
    });

    testWidgets('blank custom categories are ignored', (tester) async {
      await pumpWizard(tester);

      final notifier = notifierOf(tester);
      notifier.addCustomCategory('   ');
      await tester.pump();

      expect(stateOf(tester).selectedCategories, isEmpty);
    });
  });

  group('progress', () {
    testWidgets('reports one of three on arrival', (tester) async {
      await pumpWizard(tester);

      final progress = tester.widget<OnboardingProgress>(
        find.byType(OnboardingProgress),
      );
      expect(progress.currentIndex, 0);
      expect(progress.totalSteps, 3);
      expect(find.text('Langkah 1 dari 3'), findsOneWidget);
    });

    testWidgets('follows the step', (tester) async {
      await pumpWizard(tester);

      notifierOf(tester).goToStep(OnboardingStep.product);
      await tester.pump();

      expect(find.text('Langkah 3 dari 3'), findsOneWidget);
    });
  });

  group('persistence', () {
    testWidgets('step 1 writes the shop before advancing', (tester) async {
      // Writing per step, not at the end: a user who abandons on step 2 still
      // has the one row the app cannot run without.
      final fake = FakeOnboardingBackend();
      await pumpWizard(tester, overrides: onboardingOverrides(fake));

      await tester.enterText(find.byType(TextField).first, 'Warung Bu Sri');
      await tester.tap(find.text('Warung Makan'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ModernButton, 'Lanjut'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.savedShopName, 'Warung Bu Sri');
      expect(fake.savedBusinessType, 'warung_makan');
    });

    testWidgets('a failed save keeps the user on step 1', (tester) async {
      final fake = FakeOnboardingBackend()..failShopSave = true;
      await pumpWizard(tester, overrides: onboardingOverrides(fake));

      await tester.enterText(find.byType(TextField).first, 'Warung Bu Sri');
      await tester.tap(find.text('Warung Makan'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ModernButton, 'Lanjut'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(stateOf(tester).step, OnboardingStep.shop);
      expect(find.text('Gagal menyimpan'), findsOneWidget);
    });

    testWidgets('the onboarding marker is written before leaving',
        (tester) async {
      // The router gate reads this marker. Navigating without it sends the
      // user straight back into the wizard.
      final fake = FakeOnboardingBackend();
      await pumpWizard(tester, overrides: onboardingOverrides(fake));

      final saved = await notifierOf(tester).finish();

      expect(saved, isTrue);
      expect(fake.onboardingMarked, isTrue);
    });
  });

  group('layout', () {
    for (final width in ResponsiveWidths.all) {
      testWidgets('renders at ${ResponsiveWidths.label(width)}',
          (tester) async {
        await pumpWizard(tester, width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
