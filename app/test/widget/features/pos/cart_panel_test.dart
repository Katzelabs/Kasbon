import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/features/pos/presentation/providers/cart_provider.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/cart_bottom_sheet.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/cart_item_tile.dart';
import 'package:kasbon_pos/features/pos/presentation/widgets/cart_panel.dart';

import '../../../fixtures/mock_data.dart';
import '../../../helpers/responsive_helpers.dart';

/// A cart pre-loaded with [count] distinct products.
List<Override> cartWith(int count, {int stock = 10}) {
  return [
    cartProvider.overrideWith((ref) {
      final notifier = CartNotifier();
      for (var i = 0; i < count; i++) {
        notifier.addProduct(MockData.createProduct(
          id: 'prod-$i',
          name: 'Produk $i',
          stock: stock,
          sellingPrice: 5000,
        ));
      }
      return notifier;
    }),
  ];
}

void main() {
  group('shared content', () {
    // The point of the extraction: these assertions hold for both chromes
    // because there is only one build method behind them.
    for (final entry in {
      'sidebar': CartPanel.sidebar(onClose: () {}),
      'sheet': const CartPanel.sheet(),
    }.entries) {
      testWidgets('${entry.key} shows the items, the total and BAYAR',
          (tester) async {
        await pumpAtWidth(
          tester,
          ResponsiveWidths.expanded,
          SizedBox(width: 400, child: entry.value),
          providerOverrides: cartWith(2),
        );

        expect(find.text('Keranjang'), findsOneWidget);
        expect(find.text('2 item'), findsOneWidget);
        expect(find.byType(CartItemTile), findsNWidgets(2));
        expect(find.text('Rp10.000'), findsOneWidget);
        expect(find.text('BAYAR'), findsOneWidget);
      });

      testWidgets('${entry.key} shows the empty state with no items',
          (tester) async {
        await pumpAtWidth(
          tester,
          ResponsiveWidths.expanded,
          SizedBox(width: 400, child: entry.value),
        );

        expect(find.text('Keranjang Kosong'), findsOneWidget);
        expect(find.byType(CartItemTile), findsNothing);
        // Nothing to clear, so the destructive action is absent rather than
        // present-and-disabled.
        expect(find.text('Hapus Semua'), findsNothing);
      });
    }

    testWidgets('warns once when an item exceeds its stock', (tester) async {
      await pumpAtWidth(
        tester,
        ResponsiveWidths.expanded,
        SizedBox(width: 400, child: CartPanel.sidebar(onClose: () {})),
        providerOverrides: [
          cartProvider.overrideWith((ref) {
            final notifier = CartNotifier();
            final product = MockData.createProduct(stock: 5);
            notifier.addProduct(product);
            // Straight past the stock ceiling, which only the entity's own
            // `exceedsStock` notices - the notifier refuses this route.
            notifier.state = [notifier.state.first.copyWith(quantity: 9)];
            return notifier;
          }),
        ],
      );

      expect(
        find.text('Beberapa item melebihi stok yang tersedia'),
        findsOneWidget,
      );
    });
  });

  group('chrome', () {
    testWidgets('the docked panel has a close control and no drag handle',
        (tester) async {
      var closed = 0;

      await pumpAtWidth(
        tester,
        ResponsiveWidths.expanded,
        SizedBox(width: 400, child: CartPanel.sidebar(onClose: () => closed++)),
        providerOverrides: cartWith(1),
      );

      expect(find.byKey(CartPanel.dragHandleKey), findsNothing);
      expect(find.byKey(CartPanel.closeButtonKey), findsOneWidget);

      await tester.tap(find.byKey(CartPanel.closeButtonKey));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('the draggable sheet has a drag handle and no close control',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await pumpAtWidth(
        tester,
        ResponsiveWidths.compact,
        SizedBox(
          width: 375,
          child: CartPanel.sheet(scrollController: controller),
        ),
        providerOverrides: cartWith(1),
      );

      expect(find.byKey(CartPanel.dragHandleKey), findsOneWidget);
      expect(find.byKey(CartPanel.closeButtonKey), findsNothing);
    });

    testWidgets('the side sheet drops the handle - it does not drag',
        (tester) async {
      // Same chrome, no scroll controller. `ModernBottomSheet.showAdaptive`
      // presents this form on a wide window, where the sheet is pinned to the
      // right edge and a drag affordance would promise a gesture that is not
      // there.
      await pumpAtWidth(
        tester,
        ResponsiveWidths.large,
        const SizedBox(width: 400, child: CartPanel.sheet()),
        providerOverrides: cartWith(1),
      );

      expect(find.byKey(CartPanel.dragHandleKey), findsNothing);
      expect(find.byKey(CartPanel.closeButtonKey), findsNothing);
    });
  });

  group('clear cart', () {
    testWidgets('asks before emptying, and leaves the cart alone on Batal',
        (tester) async {
      final container = ProviderContainer(overrides: cartWith(2));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: CartPanel.sidebar(onClose: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus Semua'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Semua Item?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider), hasLength(2));
    });

    testWidgets('empties the cart on confirm', (tester) async {
      final container = ProviderContainer(overrides: cartWith(2));
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: CartPanel.sidebar(onClose: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus Semua'));
      await tester.pumpAndSettle();
      // The dialog's confirm button carries the same label as the trigger, so
      // reach for the one inside the dialog.
      await tester.tap(find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Hapus Semua'),
      ));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider), isEmpty);
    });
  });

  testWidgets('CartBottomSheet is now a presentation wrapper around CartPanel',
      (tester) async {
    await pumpAtWidth(
      tester,
      ResponsiveWidths.compact,
      const SizedBox(width: 375, child: CartBottomSheet()),
      providerOverrides: cartWith(1),
    );

    final panel = tester.widget<CartPanel>(find.byType(CartPanel));
    expect(panel.chrome, CartPanelChrome.sheet);
  });
}
