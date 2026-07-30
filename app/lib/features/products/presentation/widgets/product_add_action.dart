import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';

/// "Tambah Produk", as it appears in the product list's header.
///
/// ## Why the header and not the body
///
/// The action used to live in the filter card, which put the screen's primary
/// button in the middle of the scrolling content - it scrolled away, and inside
/// a narrow master pane it had to shrink to an icon to share a row with a view
/// toggle and a sort dropdown. The header has room for it at every width off a
/// phone, spans the whole content area regardless of what the body has split
/// into, and sits beside the avatar where the other screen-level actions are.
///
/// ## Nothing at `compact`
///
/// A phone keeps its floating button, so this renders nothing there rather than
/// crowding a 375dp header with a title, a button and an avatar - and rather
/// than offering the same action twice. The pane draws the FAB under the same
/// condition (see `ProductListPane`), so the two cannot both appear or both go
/// missing.
///
/// The tier read here is the *header's* space - the content area beside the
/// navigation rail - not a pane's. The header spans the whole of it, which is
/// why a detail panel squeezing the list below 600dp does not take this button
/// away with it.
class ProductAddAction extends StatelessWidget {
  const ProductAddAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) return const SizedBox.shrink();

    return Padding(
      // The avatar to the right carries its own 8dp; this keeps the button off
      // it without doubling the gap at the bar's trailing edge.
      padding: const EdgeInsets.only(right: AppDimensions.spacing8),
      child: ModernButton.primary(
        onPressed: () => context.go(AppRoutes.productAdd),
        leadingIcon: Icons.add,
        // Labelled where the words fit. At `medium` - a tablet in portrait,
        // where the header also holds a title and an avatar - it drops to
        // "Tambah", the same instruction in half the width.
        child: Text(
          context.isAtLeast(Breakpoint.expanded) ? 'Tambah Produk' : 'Tambah',
        ),
      ),
    );
  }
}
