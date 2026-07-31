import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/modern/modern.dart';

/// Asks before throwing away edits.
///
/// All three settings forms let you type into them and then walk away, losing
/// everything silently - no prompt, no draft, no hint that the Simpan button
/// was the only thing that would have kept the work.
///
/// Guarding this needs two doors covered, not one. [PopScope] catches the
/// system back gesture and the Android hardware button, but the app bar's own
/// back control calls `context.pop()` directly, which is an imperative pop that
/// no route-level guard ever sees. So the screens route their `onBack` through
/// [maybePop] and let [UnsavedChangesGuard] handle everything else.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  /// Whether there is anything worth warning about.
  final bool isDirty;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldLeave = await confirmDiscard(context);
        if (shouldLeave && context.mounted) {
          context.pop();
        }
      },
      child: child,
    );
  }

  /// Pops unless there are unsaved edits the user decides to keep.
  ///
  /// This is what an explicit back control should call, since a plain
  /// `context.pop()` bypasses the guard above entirely.
  static Future<void> maybePop(BuildContext context, {required bool isDirty}) async {
    if (isDirty) {
      final shouldLeave = await confirmDiscard(context);
      if (!shouldLeave || !context.mounted) return;
    }
    if (context.mounted) context.pop();
  }

  /// The prompt itself. Returns whether the user chose to discard.
  ///
  /// "Lanjut Edit" rather than "Batal" for the safe option: with a destructive
  /// confirm, "Batal" is ambiguous about which action it cancels.
  static Future<bool> confirmDiscard(BuildContext context) async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Buang Perubahan?',
      message: 'Perubahan yang belum disimpan akan hilang.',
      confirmLabel: 'Buang',
      cancelLabel: 'Lanjut Edit',
      isDestructive: true,
    );
    return confirmed == true;
  }
}
