import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/cart_provider.dart';
import '../providers/payment_provider.dart';

/// Debt payment dialog for recording hutang transactions
///
/// Requires customer name to identify who owes money.
/// Shows total amount prominently in warning color.
class DebtPaymentDialog extends ConsumerStatefulWidget {
  const DebtPaymentDialog({super.key});

  /// Show the debt payment dialog
  /// Returns true if payment was successful, false if cancelled
  static Future<bool?> show(BuildContext context) {
    return ModernDialog.show<bool>(
      context,
      dismissible: false,
      child: const DebtPaymentDialog(),
    );
  }

  @override
  ConsumerState<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends ConsumerState<DebtPaymentDialog> {
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();
  String? _customerNameError;

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final customerName = _customerNameController.text.trim();

    if (customerName.isEmpty) {
      setState(() {
        _customerNameError = 'Nama pelanggan harus diisi';
      });
      return false;
    }

    setState(() {
      _customerNameError = null;
    });
    return true;
  }

  Future<void> _processDebtPayment() async {
    if (!_validateForm()) {
      return;
    }

    // Process debt payment
    await ref.read(paymentProvider.notifier).processDebtPayment(
          customerName: _customerNameController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    final paymentState = ref.read(paymentProvider);

    if (paymentState.isSuccess && mounted) {
      // Close dialog and navigate to success screen
      Navigator.pop(context, true);

      final transactionId = paymentState.completedTransaction!.id;
      context.go('/pos/success/$transactionId');
    } else if (paymentState.hasError && mounted) {
      ModernToast.error(context, paymentState.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final paymentState = ref.watch(paymentProvider);
    final canSubmit = !paymentState.isProcessing;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.credit_card_off_outlined,
                      color: AppColors.warning,
                      size: AppDimensions.iconLarge,
                    ),
                    SizedBox(width: AppDimensions.spacing8),
                    Text(
                      'Pembayaran Hutang',
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
                ModernIconButton(
                  icon: Icons.close,
                  onPressed: paymentState.isProcessing
                      ? null
                      : () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Total display with warning color
            ModernGradientCard.warning(
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              child: Column(
                children: [
                  Text(
                    'Total Hutang',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  Text(
                    CurrencyFormatter.format(total),
                    style: AppTextStyles.h1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Customer name input (required)
            ModernTextField(
              controller: _customerNameController,
              label: 'Nama Pelanggan *',
              hint: 'Masukkan nama pelanggan',
              variant: ModernInputVariant.filled,
              autofocus: true,
              errorText: _customerNameError,
              leading: const Icon(Icons.person_outline),
              onChanged: (_) {
                if (_customerNameError != null) {
                  setState(() {
                    _customerNameError = null;
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.spacing16),

            // Notes input (optional)
            ModernTextField(
              controller: _notesController,
              label: 'Catatan (Opsional)',
              hint: 'Tambahkan catatan jika perlu',
              variant: ModernInputVariant.filled,
              leading: const Icon(Icons.notes_outlined),
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Warning message
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                    size: AppDimensions.iconMedium,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      'Transaksi akan dicatat sebagai hutang dan perlu dilunasi nanti.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ModernButton.outline(
                    onPressed: paymentState.isProcessing
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  flex: 2,
                  child: ModernButton.primary(
                    onPressed: canSubmit ? _processDebtPayment : null,
                    isLoading: paymentState.isProcessing,
                    leadingIcon: Icons.save_outlined,
                    child: const Text('Simpan Hutang'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
