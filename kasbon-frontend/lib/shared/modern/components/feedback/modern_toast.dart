import 'package:flutter/widgets.dart';

import '../../utils/modern_variants.dart';
import 'modern_toast_controller.dart';

/// A Modern-styled top-right stacked toast notification system.
///
/// Toasts appear in the top-right corner of the screen, stacked with the
/// newest on top. Each toast auto-dismisses after [duration] (default 3s)
/// and exposes a manual close button. Multiple toasts can be visible
/// simultaneously (capped at 5; oldest drops on overflow).
///
/// The [BuildContext] parameter is preserved for source compatibility but
/// no longer required — the underlying [ToastController] resolves the root
/// overlay independently.
///
/// Example:
/// ```dart
/// ModernToast.success(context, 'Produk berhasil disimpan!');
/// ModernToast.error(context, 'Gagal menyimpan produk');
/// ```
class ModernToast {
  ModernToast._();

  /// Shows a toast with the specified [variant].
  static void show(
    BuildContext context, {
    required String message,
    ModernToastVariant variant = ModernToastVariant.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastController.instance.push(
      message: message,
      variant: variant,
      duration: duration,
    );
  }

  /// Shows a success toast (green).
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastController.instance.push(
      message: message,
      variant: ModernToastVariant.success,
      duration: duration,
    );
  }

  /// Shows an error toast (red).
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastController.instance.push(
      message: message,
      variant: ModernToastVariant.error,
      duration: duration,
    );
  }

  /// Shows a warning toast (amber).
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastController.instance.push(
      message: message,
      variant: ModernToastVariant.warning,
      duration: duration,
    );
  }

  /// Shows an info toast (blue).
  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastController.instance.push(
      message: message,
      variant: ModernToastVariant.info,
      duration: duration,
    );
  }

  /// Removes every active toast immediately.
  static void hide(BuildContext context) {
    ToastController.instance.clear();
  }
}
