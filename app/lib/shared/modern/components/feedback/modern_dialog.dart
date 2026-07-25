import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
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
class ModernDialog extends StatelessWidget {
  const ModernDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.content,
    this.actions,
    this.dismissible = true,
    this.contentPadding,
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
          ModernButton.text(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: AppDimensions.spacing12),
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
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
