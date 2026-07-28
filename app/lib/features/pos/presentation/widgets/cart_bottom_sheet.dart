import 'package:flutter/material.dart';

import '../../../../shared/modern/modern.dart';
import 'cart_panel.dart';

/// Presents the cart as a modal.
///
/// All of the content lives in [CartPanel]; what is left here is the decision
/// about *how* to present it. Before RESP_06 this file carried its own copy of
/// the header, item list, stock warning and footer, which had already drifted
/// from the docked copy in `pos_screen`.
class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({
    super.key,
    this.scrollController,
  });

  final ScrollController? scrollController;

  /// Show the cart.
  ///
  /// A draggable bottom sheet on a phone, a right-edge side sheet on a desktop
  /// window. `showAdaptiveDraggable` rather than `showAdaptive` because the
  /// body below is a list with a pinned footer under it - an `Expanded` inside
  /// a scroll view has no height to expand into.
  static Future<void> show(BuildContext context) {
    return ModernBottomSheet.showAdaptiveDraggable<void>(
      context,
      builder: (context, scrollController) => CartBottomSheet(
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CartPanel.sheet(scrollController: scrollController);
  }
}
