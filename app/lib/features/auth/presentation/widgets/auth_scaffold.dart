import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';

/// The frame both auth screens sit in.
///
/// Login and register are the only two routes outside the shell, so nothing
/// above them supplies a background, a width clamp or a safe area - they each
/// built their own, and drifted. This is that frame, once.
///
/// ## Why the tier is read out here
///
/// [ModernContentColumn.form] clamps to 560dp *and re-scopes the breakpoint to
/// the clamped width*, which is the whole point of it. The consequence is that
/// inside the column every window reports `compact`, because 560 < 600. So a
/// layout decision that depends on how much screen there actually is has to be
/// made out here, above the clamp, where the tier still describes the window.
///
/// Reading it after the clamp is the subtle version of this mistake: the code
/// looks right, `context.isCompact` is true on a 2560dp monitor, and the
/// desktop branch is simply never taken.
///
/// ## What the tier decides
///
/// Whether the form is framed in a card. On a phone it is not: a card inset
/// inside a 375dp screen spends horizontal room the fields need and reads as a
/// box drawn around the whole page. From `medium` up it is, because a 560dp
/// column floating in the middle of a 1600dp window with no edge to it looks
/// unfinished rather than airy.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.leading,
  });

  /// The form, header and links - everything that scrolls.
  final Widget child;

  /// Optional top-left affordance, pinned above the card. Register puts its
  /// back button here so the button belongs to the *screen* rather than
  /// sitting inside the card as one more form row.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final framed = context.isAtLeast(Breakpoint.medium);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        // A single soft wash of brand colour behind the header, fading out
        // before the fields start. Enough to stop the screen reading as a
        // grey form on grey, not so much that it competes with the logo.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryContainer,
              AppColors.background,
            ],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: ModernContentColumn.form(
            // Centred, deliberately. This is the one screen shape that is a
            // card floating in its viewport; everywhere else content shorter
            // than the screen belongs at the top, which is why the column
            // aligns that way by default.
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null) ...[
                    Align(alignment: Alignment.centerLeft, child: leading),
                    const SizedBox(height: AppDimensions.spacing12),
                  ],
                  if (framed)
                    ModernCard.elevated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing32,
                        vertical: AppDimensions.spacing40,
                      ),
                      child: child,
                    )
                  else
                    child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
