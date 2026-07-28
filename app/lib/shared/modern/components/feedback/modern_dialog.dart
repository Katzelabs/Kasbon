import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../button/modern_button.dart';

/// A Modern-styled dialog with consistent theming
///
/// Example:
/// ```dart
/// ModernDialog.confirm(
///   context,
///   title: 'Hapus Produk',
///   message: 'Apakah Anda yakin ingin menghapus produk ini?',
///   isDestructive: true,
/// );
/// ```
///
/// ## Width
///
/// Every dialog is clamped, and [maxWidth] is how a caller widens one. The
/// default suits a confirmation - a prompt does not become easier to read for
/// spanning a 1600dp monitor - so only dialogs carrying real content
/// (a payment form, a picker) pass anything else.
///
/// This used to be true of the widget but not of [show], which wrapped its
/// child in a bare `Dialog` with no clamp at all. Two callers worked around
/// that by clamping themselves; both now pass [maxWidth] instead.
class ModernDialog extends StatelessWidget {
  const ModernDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.content,
    this.actions,
    this.dismissible = true,
    this.contentPadding,
    this.maxWidth,
  });

  /// The dialog title text
  final String? title;

  /// Custom title widget (overrides [title])
  final Widget? titleWidget;

  /// The dialog content widget
  final Widget? content;

  /// Action buttons at the bottom
  final List<Widget>? actions;

  /// Whether the dialog can be dismissed by tapping outside
  final bool dismissible;

  /// Custom content padding
  final EdgeInsets? contentPadding;

  /// Widest the dialog may grow.
  ///
  /// Defaults to the tier width in [ContentLayout] - 420 / 560 / 640. Pass a
  /// value only to override that ramp, not to reach the window edge; there is
  /// no tier at which a dialog spanning 1600dp is the right answer.
  final double? maxWidth;

  /// Shows a confirmation dialog with Yes/No buttons
  ///
  /// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Ya',
    String cancelLabel = 'Batal',
    bool isDestructive = false,
    bool dismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => ModernDialog(
        title: title,
        dismissible: dismissible,
        content: message != null
            ? Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        actions: [
          // No spacer between the two: the actions row is an OverflowBar,
          // which owns the gap and would treat a SizedBox as a third button
          // to stack when the labels do not fit.
          ModernButton.text(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          isDestructive
              ? ModernButton.destructive(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                )
              : ModernButton.primary(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
        ],
      ),
    );
  }

  /// Shows an alert dialog with a single OK button
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String buttonLabel = 'OK',
    bool dismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => ModernDialog(
        title: title,
        dismissible: dismissible,
        content: message != null
            ? Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        actions: [
          ModernButton.primary(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  /// Shows an error dialog
  static Future<void> error(
    BuildContext context, {
    required String title,
    String? message,
    String buttonLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ModernDialog(
        titleWidget: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppDimensions.iconLarge,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h4.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
        content: message != null
            ? Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        actions: [
          ModernButton.primary(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a success dialog
  static Future<void> success(
    BuildContext context, {
    required String title,
    String? message,
    String buttonLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ModernDialog(
        titleWidget: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: AppDimensions.iconLarge,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h4.copyWith(color: AppColors.success),
              ),
            ),
          ],
        ),
        content: message != null
            ? Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        actions: [
          ModernButton.primary(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a custom dialog
  ///
  /// The child is framed exactly as the widget's own `build` frames its
  /// content: same shape, same clamp, same tier-aware inset. That symmetry is
  /// the fix - this used to hand the child a bare `Dialog` with no maximum
  /// width, so `show` and `build` disagreed about how wide a dialog is.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
    double? maxWidth,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => ModernDialogFrame(
        maxWidth: maxWidth,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernDialogFrame(
      maxWidth: maxWidth,
      child: Padding(
        padding:
            contentPadding ?? const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            if (titleWidget != null)
              titleWidget!
            else if (title != null)
              Text(
                title!,
                style: AppTextStyles.h4,
              ),
            // Content
            if (content != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              content!,
            ],
            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacing24),
              // OverflowBar rather than Row: Indonesian action labels are
              // long ("Simpan Perubahan", "Hapus Semua Item"), and two of them
              // side by side overflow a 420dp dialog on a small phone. This
              // stacks them instead of painting the yellow stripe.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppDimensions.spacing12,
                overflowSpacing: AppDimensions.spacing8,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The shell every [ModernDialog] sits in: rounded surface, width clamp, and
/// an inset that shrinks with the window.
///
/// Public because [ModernDialog.show] needs to apply the identical frame to a
/// child it does not otherwise wrap, and because the date range picker builds
/// its own dialog body and wants the same edges.
class ModernDialogFrame extends StatelessWidget {
  const ModernDialogFrame({
    super.key,
    required this.child,
    this.maxWidth,
    this.backgroundColor,
  });

  final Widget child;

  /// Widest the dialog may grow. Defaults to [maxWidthFor].
  final double? maxWidth;

  /// Surface colour. Pass [Colors.transparent] when the child paints its own.
  final Color? backgroundColor;

  /// Default dialog width for the current tier.
  ///
  /// Reads the *window*, not a container: a dialog floats above the whole
  /// window and is unaffected by the pane its opener happens to sit in. That
  /// is also what it gets in practice - `showDialog` builds against the root
  /// navigator, above every pane scope.
  static double maxWidthFor(BuildContext context) =>
      switch (context.windowBreakpoint) {
        Breakpoint.compact => ContentLayout.dialogCompact,
        Breakpoint.medium => ContentLayout.dialogMedium,
        Breakpoint.expanded || Breakpoint.large => ContentLayout.dialogLarge,
      };

  /// Space between the dialog and the window edge, by tier.
  ///
  /// Material's default is a flat 40dp horizontal, which on a 360dp phone
  /// spends 80dp - over a fifth of the screen - on margin.
  static EdgeInsets insetPaddingFor(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: context.responsive<double>(
          compact: AppDimensions.spacing16,
          medium: AppDimensions.spacing24,
          expanded: AppDimensions.spacing40,
        ),
        vertical: AppDimensions.spacing24,
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: insetPaddingFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? maxWidthFor(context),
        ),
        child: child,
      ),
    );
  }
}
