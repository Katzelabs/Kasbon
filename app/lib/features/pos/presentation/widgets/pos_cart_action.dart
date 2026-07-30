import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_layout_provider.dart';
import 'cart_bottom_sheet.dart';

/// The cart control in the POS header.
///
/// ## One button, two jobs, chosen by the same rule the layout uses
///
/// - **`expanded` and up**, where the cart is docked beside the grid: this
///   toggles it. It replaces the floating button that used to be the only way
///   back to a collapsed cart - a FAB that sat over the bottom-right products
///   and, being the way to *reopen* the cart, was the one control that had to be
///   findable while the cart was hidden.
/// - **`medium`**: the cart is a modal here, so this opens it. Previously the
///   only way in was tapping the summary bar, which is hidden while the cart is
///   empty - so an empty cart was unreachable and there was nowhere to check
///   that it was in fact empty.
///
/// Both read [PosLayout.showsCartSidebar], the same predicate `PosScreen` uses
/// to pick its layout, so the button cannot end up toggling a panel that is not
/// there.
///
/// ## Nothing at `compact`
///
/// A phone keeps the floating summary bar and its sheet. That bar carries the
/// total and the checkout affordance, which a header icon cannot, and a 375dp
/// header has no room to spare beside the title and the avatar.
class PosCartAction extends ConsumerWidget {
  const PosCartAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.isCompact) return const SizedBox.shrink();

    final itemCount = ref.watch(cartItemCountProvider);
    final togglesSidebar = PosLayout.showsCartSidebar(context.breakpoint);
    final isSidebarOpen = ref.watch(posCartExpandedProvider);

    // Open state is worth showing only where the button has one: as a toggle it
    // is the cart's on/off switch, as a sheet opener it is not.
    final isActive = togglesSidebar && isSidebarOpen;

    return Padding(
      // The avatar to the right carries its own 8dp; this keeps the button off
      // it without doubling the gap at the bar's trailing edge.
      padding: const EdgeInsets.only(right: AppDimensions.spacing8),
      child: Badge(
        isLabelVisible: itemCount > 0,
        label: Text(itemCount > 99 ? '99+' : '$itemCount'),
        child: ModernIconButton.tonal(
          icon: isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined,
          tooltip: !togglesSidebar
              ? 'Keranjang'
              : isSidebarOpen
                  ? 'Sembunyikan Keranjang'
                  : 'Tampilkan Keranjang',
          onPressed: () {
            if (togglesSidebar) {
              ref.read(posCartExpandedProvider.notifier).state = !isSidebarOpen;
            } else {
              CartBottomSheet.show(context);
            }
          },
        ),
      ),
    );
  }
}
