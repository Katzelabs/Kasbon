import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/services/payment_proof/payment_proof_storage.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/cart_provider.dart';
import '../providers/payment_provider.dart';
import 'customer_name_field.dart';
import 'debt_payment_dialog.dart';
import 'payment_proof_capture.dart';
import 'transaction_success_dialog.dart';

/// Payment dialog for processing payments
///
/// Offers Tunai and QRIS inline, and hands over to [DebtPaymentDialog] for
/// hutang - which is a different transaction with a required customer name, not
/// a third mode of this one.
///
/// The two inline methods differ in exactly one thing: cash needs an amount and
/// works out change, QRIS needs neither because the customer typed the total
/// into their own wallet app and this app never sees what they typed. Everything
/// below the method picker follows from that.
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
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();

  double _cashReceived = 0;
  SelectedPaymentMethod _selectedMethod = SelectedPaymentMethod.cash;
  PickedImage? _proof;

  /// Whether the optional customer/notes fields are on screen.
  ///
  /// Collapsed by default, and that is the point. This dialog is the hottest
  /// path in the app - tap Bayar, type cash, Enter - and two permanent text
  /// fields between the amount and the Bayar button push the primary action
  /// down far enough to need a scroll on a phone. Almost no sale names a
  /// customer, so almost no sale should pay for the space.
  bool _showOptionalFields = false;

  @override
  void dispose() {
    _cashController.dispose();
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isCash => _selectedMethod == SelectedPaymentMethod.cash;

  String? get _trimmedOrNull {
    final text = _customerNameController.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _notesOrNull {
    final text = _notesController.text.trim();
    return text.isEmpty ? null : text;
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
      return;
    }

    setState(() {
      _selectedMethod = method;
    });
  }

  /// Whether the primary button can fire right now.
  ///
  /// Cash has to cover the total. QRIS has nothing to check - the cashier
  /// pressing the button *is* the check - so it is always ready.
  bool _canSubmit(double total, PaymentState paymentState) {
    if (paymentState.isProcessing) return false;
    return _isCash ? _cashReceived >= total : true;
  }

  Future<void> _submit() async {
    final total = ref.read(cartTotalProvider);

    if (_isCash && _cashReceived < total) {
      ModernToast.error(context, 'Uang yang diterima kurang dari total');
      return;
    }

    final notifier = ref.read(paymentProvider.notifier);

    if (_isCash) {
      await notifier.processCashPayment(
        cashReceived: _cashReceived,
        customerName: _trimmedOrNull,
        notes: _notesOrNull,
      );
    } else {
      await notifier.processQrisPayment(
        proof: _proof,
        customerName: _trimmedOrNull,
        notes: _notesOrNull,
      );
    }

    final paymentState = ref.read(paymentProvider);

    if (paymentState.isSuccess && mounted) {
      // Close this dialog, then confirm the sale in a modal over the POS grid.
      // The root navigator's context is captured first: after the pop, this
      // State's context is defunct and cannot host a dialog.
      final navigator = Navigator.of(context, rootNavigator: true);
      final transaction = paymentState.completedTransaction!;

      Navigator.pop(context, true);
      await TransactionSuccessDialog.show(navigator.context, transaction);
    } else if (paymentState.hasError && mounted) {
      ModernToast.error(context, paymentState.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final paymentState = ref.watch(paymentProvider);
    final canSubmit = _canSubmit(total, paymentState);

    // Enter confirms and Esc cancels, so a cashier can finish a sale without
    // leaving the number pad. Both are no-ops while the payment is in flight -
    // a double Enter must not submit twice.
    //
    // No width clamp here: ModernDialog.show applies the tier width now, which
    // is what the hand-rolled 640 was standing in for.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (canSubmit) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (canSubmit) _submit();
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
                    icon: Icons.qr_code_2_outlined,
                    label: 'QRIS',
                    isSelected: _selectedMethod == SelectedPaymentMethod.qris,
                    onTap: () =>
                        _selectPaymentMethod(SelectedPaymentMethod.qris),
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

            if (_isCash)
              _CashSection(
                controller: _cashController,
                total: total,
                cashReceived: _cashReceived,
                onCashChanged: (value) {
                  setState(() => _cashReceived = value.toDouble());
                },
                onSubmitted: () {
                  if (canSubmit) _submit();
                },
                onQuickCash: _setCash,
              )
            else
              _QrisSection(
                total: total,
                proof: _proof,
                onProofChanged: (proof) => setState(() => _proof = proof),
              ),

            const SizedBox(height: AppDimensions.spacing16),

            _OptionalFields(
              expanded: _showOptionalFields,
              customerNameController: _customerNameController,
              notesController: _notesController,
              onToggle: () => setState(
                () => _showOptionalFields = !_showOptionalFields,
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
                  child: ModernButton.primary(
                    onPressed: canSubmit ? _submit : null,
                    isLoading: paymentState.isProcessing,
                    child: Text(_isCash ? 'Bayar' : 'Sudah Bayar'),
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

/// Amount received, quick notes, and the change to hand back.
class _CashSection extends StatelessWidget {
  const _CashSection({
    required this.controller,
    required this.total,
    required this.cashReceived,
    required this.onCashChanged,
    required this.onSubmitted,
    required this.onQuickCash,
  });

  final TextEditingController controller;
  final double total;
  final double cashReceived;
  final ValueChanged<int> onCashChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<double> onQuickCash;

  @override
  Widget build(BuildContext context) {
    final change = cashReceived - total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernCurrencyField(
          controller: controller,
          label: 'Uang Diterima',
          variant: ModernInputVariant.filled,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: onCashChanged,
          // The field owns Enter while it has focus - a text field consumes
          // the key before the dialog's CallbackShortcuts ever sees it - so
          // the fast path has to be wired here as well as there.
          onSubmitted: (_) => onSubmitted(),
        ),
        const SizedBox(height: AppDimensions.spacing16),

        // Quick cash buttons
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            _QuickCashButton(amount: 10000, onPressed: () => onQuickCash(10000)),
            _QuickCashButton(amount: 20000, onPressed: () => onQuickCash(20000)),
            _QuickCashButton(amount: 50000, onPressed: () => onQuickCash(50000)),
            _QuickCashButton(
                amount: 100000, onPressed: () => onQuickCash(100000)),
            ModernButton.secondary(
              size: ModernSize.small,
              onPressed: () => onQuickCash(total),
              child: const Text('Uang Pas'),
            ),
          ],
        ),

        // Change display
        if (cashReceived > 0) ...[
          const SizedBox(height: AppDimensions.spacing24),
          ModernCard.filled(
            color: change >= 0 ? AppColors.successLight : AppColors.errorLight,
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    change >= 0 ? 'Kembalian' : 'Kurang',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: change >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                // Not flexible, deliberately: a Row lays its inflexible
                // children out first, so the amount always gets the width it
                // needs and the label ellipsises instead. Truncating money to
                // fit a label is the wrong way round.
                Text(
                  CurrencyFormatter.format(change.abs()),
                  style: AppTextStyles.h4.copyWith(
                    color: change >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// What to do at the counter for a QRIS sale, and somewhere to put the photo.
///
/// There is no amount field. On QRIS statis the customer reads the total off
/// the cashier's screen and types it into their own wallet app, so the number
/// below is an instruction, not an input - which is also why it repeats the
/// total the header already shows. The cashier reads this one out loud.
class _QrisSection extends StatelessWidget {
  const _QrisSection({
    required this.total,
    required this.proof,
    required this.onProofChanged,
  });

  final double total;
  final PickedImage? proof;
  final ValueChanged<PickedImage?> onProofChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernCard.filled(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            children: [
              const Icon(
                Icons.qr_code_2,
                size: AppDimensions.iconXLarge,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                'Minta pelanggan scan QRIS di meja',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                'lalu masukkan ${CurrencyFormatter.format(total)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        PaymentProofCapture(proof: proof, onProofChanged: onProofChanged),
      ],
    );
  }
}

/// Customer name and notes, behind a disclosure.
class _OptionalFields extends StatelessWidget {
  const _OptionalFields({
    required this.expanded,
    required this.customerNameController,
    required this.notesController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController customerNameController;
  final TextEditingController notesController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ModernButton.text(
          size: ModernSize.small,
          onPressed: onToggle,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: AppDimensions.iconSmall),
              SizedBox(width: AppDimensions.spacing4),
              Text('Catatan / nama pelanggan'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerNameField(controller: customerNameController),
        const SizedBox(height: AppDimensions.spacing12),
        ModernTextField(
          controller: notesController,
          label: 'Catatan (opsional)',
          leading: const Icon(Icons.notes_outlined),
          // Single line on purpose. A multiline field wants Enter to insert a
          // newline, and Enter in this dialog takes the payment - a cashier
          // reaching for a second line would commit the sale mid-word.
          textInputAction: TextInputAction.done,
        ),
      ],
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
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacing16,
          horizontal: AppDimensions.spacing8,
        ),
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
            // Three buttons where there were two, so a label now has a third of
            // the width instead of a half. "Hutang" fits; a longer method added
            // later would not, and should shrink rather than overflow.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? effectiveColor : AppColors.textSecondary,
                ),
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
