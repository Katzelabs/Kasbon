import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/errors/auth_error_codes.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../shared/providers/providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../backup/domain/entities/backup_metadata.dart';
import '../../../backup/presentation/providers/backup_provider.dart';

/// What the user did with [DeleteAccountDialog].
enum DeleteAccountOutcome {
  /// Dismissed, or cancelled. Nothing happened.
  cancelled,

  /// The account is gone. The session went with it, so the router is already
  /// on its way to `/login` by the time the caller sees this.
  deleted,

  /// They took the offer to export their data first. The caller sends them to
  /// the backup screen; deleting is something they come back and do.
  backupRequested,
}

/// Confirms - and then performs - permanent deletion of the signed-in account.
///
/// Two gates, and they guard different things. Typing HAPUS is the "I have read
/// the list above" gate, matching `ClearDataConfirmationDialog`, which destroys
/// a strict subset of what this does. The password is the "I am the owner"
/// gate: a POS device sits signed in on a counter all day, so the session is
/// not evidence of anything, and this is the one action in the app that a
/// passer-by could not undo.
///
/// The deletion runs here rather than in the caller because the dialog owns the
/// only state worth showing while it is in flight: everything disabled, one
/// spinner, and a wrong password shown against the field that was wrong.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  /// The word that unlocks the button. Same as the clear-data dialog: users who
  /// have met one of these should not have to learn a second vocabulary.
  static const String confirmWord = 'HAPUS';

  static Future<DeleteAccountOutcome> show(BuildContext context) async {
    final outcome = await showDialog<DeleteAccountOutcome>(
      context: context,
      // Not dismissible by tapping outside, unlike most dialogs here: the
      // password field brings up a keyboard, and a mistimed tap on the scrim
      // while it animates should not silently drop what was typed.
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
    return outcome ?? DeleteAccountOutcome.cancelled;
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _deleting = false;

  /// Shown against the password field when the failure was the password, and
  /// in the strip above the buttons otherwise. A network error under the
  /// password field would blame the wrong thing.
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onChanged);
    _confirmController.removeListener(_onChanged);
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Clearing the last failure as soon as anything is typed: an error left
    // under a field the user has already corrected reads as a live complaint
    // about the value now in it.
    if (_passwordError != null || _generalError != null) {
      setState(() {
        _passwordError = null;
        _generalError = null;
      });
      return;
    }
    setState(() {});
  }

  bool get _canDelete =>
      !_deleting &&
      _passwordController.text.isNotEmpty &&
      _confirmController.text.trim() == DeleteAccountDialog.confirmWord;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _passwordError = null;
      _generalError = null;
    });

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(password: _passwordController.text);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(DeleteAccountOutcome.deleted);
      return;
    }

    final state = ref.read(authNotifierProvider);
    final message = state.errorMessage ?? 'Gagal menghapus akun';
    setState(() {
      _deleting = false;
      if (state.errorCode == AuthErrorCodes.wrongPassword) {
        _passwordError = message;
      } else {
        _generalError = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(dataCountsProvider);
    final email = ref.watch(userInfoProvider).email;

    // Height only - `architecture_test` forbids reading the width here, and a
    // dialog is sized by its content anyway. The cap keeps a long counts list
    // from pushing the buttons off a small phone, and the viewInsets term keeps
    // them above the keyboard the password field raises.
    final maxHeight = MediaQuery.of(context).size.height * 0.85 -
        MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      // Nothing may leave while the request is in flight - not the back button
      // either. There is no cancelling a deletion half way.
      canPop: !_deleting,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.all(AppDimensions.spacing16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_remove_rounded,
                            color: AppColors.error,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        const Text(
                          'Hapus Akun?',
                          style: AppTextStyles.h3,
                          textAlign: TextAlign.center,
                        ),
                        if (email != null) ...[
                          const SizedBox(height: AppDimensions.spacing4),
                          Text(
                            email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppDimensions.spacing16),
                        _WhatIsDestroyed(countsAsync: countsAsync),
                        const SizedBox(height: AppDimensions.spacing16),
                        const _PermanentWarning(),
                        const SizedBox(height: AppDimensions.spacing16),
                        _buildBackupOffer(),
                        const SizedBox(height: AppDimensions.spacing16),
                        ModernTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Masukkan password Anda',
                          obscureText: _obscurePassword,
                          enabled: !_deleting,
                          errorText: _passwordError,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: const [AutofillHints.password],
                          trailing: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: AppDimensions.iconMedium,
                            color: AppColors.textSecondary,
                          ),
                          onTrailingTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ketik "${DeleteAccountDialog.confirmWord}" untuk '
                            'konfirmasi:',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        ModernTextField(
                          controller: _confirmController,
                          hint: 'Ketik ${DeleteAccountDialog.confirmWord}',
                          enabled: !_deleting,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        if (_generalError != null) ...[
                          const SizedBox(height: AppDimensions.spacing16),
                          _ErrorStrip(message: _generalError!),
                        ],
                        const SizedBox(height: AppDimensions.spacing24),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ModernButton.outline(
                        onPressed: _deleting
                            ? null
                            : () => Navigator.of(context)
                                .pop(DeleteAccountOutcome.cancelled),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: ModernButton.destructive(
                        onPressed: _canDelete ? _delete : null,
                        child: _deleting
                            ? const ModernLoading.small()
                            : const Text('Hapus Akun'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The export-first offer.
  ///
  /// Deliberately a way out of this dialog rather than a step inside it: the
  /// backup screen already does this properly, including where the file goes,
  /// and half of it reimplemented in a dialog that is about to delete the data
  /// is the worst place for a bug.
  Widget _buildBackupOffer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingin menyimpan data Anda dulu?',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            'Backup mengunduh seluruh produk dan transaksi Anda sebagai satu '
            'file JSON.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          ModernButton.text(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context)
                    .pop(DeleteAccountOutcome.backupRequested),
            child: const Text('Buat Backup Dulu'),
          ),
        ],
      ),
    );
  }
}

/// The list the dialog is required to show: what deletion actually destroys.
///
/// Counted, not described. "Semua data Anda" is true and means nothing; "312
/// transaksi" is the number that makes someone stop and think.
class _WhatIsDestroyed extends StatelessWidget {
  const _WhatIsDestroyed({required this.countsAsync});

  final AsyncValue<DataCounts> countsAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yang akan dihapus permanen:',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          countsAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: ModernLoading.small()),
            ),
            // A failed count must not hide the list. The rows are still true;
            // only the numbers are missing, so they are replaced with a dash
            // rather than with nothing.
            error: (_, __) => const _CountedRows(counts: null),
            data: (counts) => _CountedRows(counts: counts),
          ),
        ],
      ),
    );
  }
}

class _CountedRows extends StatelessWidget {
  const _CountedRows({required this.counts});

  final DataCounts? counts;

  @override
  Widget build(BuildContext context) {
    String value(int? n) => n?.toString() ?? '—';

    return Column(
      children: [
        _row('Produk', value(counts?.products)),
        _row('Transaksi', value(counts?.transactions)),
        _row('Kategori', value(counts?.categories)),
        // Not counted, because nothing counts them - but they are the one thing
        // a cascade would not have taken, and the reason the server-side
        // deletion exists at all.
        _row('Foto produk & bukti pembayaran', 'Semua'),
        _row('Profil toko & pengaturan', 'Semua'),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermanentWarning extends StatelessWidget {
  const _PermanentWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Text(
                'PERINGATAN',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Akun dan seluruh data dihapus permanen dan tidak dapat '
            'dipulihkan. Anda perlu mendaftar ulang untuk menggunakan KASBON '
            'lagi.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
