import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/cart_provider.dart';
import '../providers/payment_provider.dart';
import 'debt_payment_dialog.dart';
import '../../../../config/routes/app_router.dart';

/// Payment dialog for processing payments
///
/// Shows payment method selection (Tunai/Hutang),
/// then cash input for tunai or customer name for hutang.
class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  /// Show the payment dialog
  /// Returns true if payment was successful, false if cancelled
  static Future<bool?> show(BuildContext context) {
    return ModernDialog.show<bool>(
      context,
      dismissible: false,
      child: const PaymentDialog(),
    );
  }

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _cashController = TextEditingController();
  double _cashReceived = 0;
  SelectedPaymentMethod _selectedMethod = SelectedPaymentMethod.cash;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _setCash(double amount) {
    setState(() {
      _cashReceived = amount;
      _cashController.text = _formatCurrency(amount.toInt());
    });
  }

  String _formatCurrency(int number) {
    if (number == 0) return '';
    final chars = number.toString().split('').reversed.toList();
    final result = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) result.add('.');
      result.add(chars[i]);
    }
    return result.reversed.join();
  }

  void _selectPaymentMethod(SelectedPaymentMethod method) {
    if (method == SelectedPaymentMethod.debt) {
      // Close this dialog and open debt dialog
      Navigator.pop(context, false);
      DebtPaymentDialog.show(context);
    } else {
      setState(() {
        _selectedMethod = method;
      });
    }
  }

  Future<void> _processCashPayment() async {
    final total = ref.read(cartTotalProvider);

    if (_cashReceived < total) {
      ModernToast.error(context, 'Uang yang diterima kurang dari total');
      return;
    }

    // Process cash payment
    await ref.read(paymentProvider.notifier).processCashPayment(
          cashReceived: _cashReceived,
        );

    final paymentState = ref.read(paymentProvider);

    if (paymentState.isSuccess && mounted) {
      // Close dialog and navigate to success screen
      Navigator.pop(context, true);

      final transactionId = paymentState.completedTransaction!.id;
      context.go(AppRoutes.posSuccessPath(transactionId));
    } else if (paymentState.hasError && mounted) {
      ModernToast.error(context, paymentState.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final paymentState = ref.watch(paymentProvider);
    final change = _cashReceived - total;
    final canPay = _cashReceived >= total && !paymentState.isProcessing;

    // Enter confirms and Esc cancels, so a cashier can finish a sale without
    // leaving the number pad. Both are no-ops while the payment is in flight -
    // a double Enter must not submit twice.
    //
    // No width clamp here: ModernDialog.show applies the tier width now, which
    // is what the hand-rolled 640 was standing in for.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (canPay) _processCashPayment();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (canPay) _processCashPayment();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!paymentState.isProcessing) Navigator.pop(context, false);
        },
      },
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
                const Text(
                  'Pembayaran',
                  style: AppTextStyles.h3,
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

            // Total display
            ModernCard.filled(
              color: AppColors.primaryContainer,
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                children: [
                  Text(
                    'Total',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    CurrencyFormatter.format(total),
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Payment method selection
            Text(
              'Metode Pembayaran',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              children: [
                Expanded(
                  child: _PaymentMethodButton(
                    icon: Icons.payments_outlined,
                    label: 'Tunai',
                    isSelected: _selectedMethod == SelectedPaymentMethod.cash,
                    onTap: () =>
                        _selectPaymentMethod(SelectedPaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: _PaymentMethodButton(
                    icon: Icons.credit_card_off_outlined,
                    label: 'Hutang',
                    isSelected: _selectedMethod == SelectedPaymentMethod.debt,
                    onTap: () =>
                        _selectPaymentMethod(SelectedPaymentMethod.debt),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Cash received input (only for cash payment)
            ModernCurrencyField(
              controller: _cashController,
              label: 'Uang Diterima',
              variant: ModernInputVariant.filled,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                setState(() {
                  _cashReceived = value.toDouble();
                });
              },
              // The field owns Enter while it has focus - a text field consumes
              // the key before the dialog's CallbackShortcuts ever sees it - so
              // the fast path has to be wired here as well as there.
              onSubmitted: (_) {
                if (canPay) _processCashPayment();
              },
            ),
            const SizedBox(height: AppDimensions.spacing16),

            // Quick cash buttons
            Wrap(
              spacing: AppDimensions.spacing8,
              runSpacing: AppDimensions.spacing8,
              children: [
                _QuickCashButton(
                  amount: 10000,
                  onPressed: () => _setCash(10000),
                ),
                _QuickCashButton(
                  amount: 20000,
                  onPressed: () => _setCash(20000),
                ),
                _QuickCashButton(
                  amount: 50000,
                  onPressed: () => _setCash(50000),
                ),
                _QuickCashButton(
                  amount: 100000,
                  onPressed: () => _setCash(100000),
                ),
                ModernButton.secondary(
                  size: ModernSize.small,
                  onPressed: () => _setCash(total),
                  child: const Text('Uang Pas'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Change display
            if (_cashReceived > 0) ...[
              ModernCard.filled(
                color:
                    change >= 0 ? AppColors.successLight : AppColors.errorLight,
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      change >= 0 ? 'Kembalian' : 'Kurang',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color:
                            change >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(change.abs()),
                      style: AppTextStyles.h4.copyWith(
                        color:
                            change >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacing24),
            ],

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
                  child: ModernButton.primary(
                    onPressed: canPay ? _processCashPayment : null,
                    isLoading: paymentState.isProcessing,
                    child: const Text('Bayar'),
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

/// Payment method selection button
class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: AppDimensions.iconXLarge,
              color: isSelected ? effectiveColor : AppColors.textSecondary,
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? effectiveColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick cash button widget
class _QuickCashButton extends StatelessWidget {
  const _QuickCashButton({
    required this.amount,
    required this.onPressed,
  });

  final double amount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ModernButton.outline(
      size: ModernSize.small,
      onPressed: onPressed,
      child: Text(CurrencyFormatter.formatCompact(amount)),
    );
  }
}
