import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/get_transaction.dart';

/// Provider to fetch transaction by ID
final transactionByIdProvider = FutureProvider.autoDispose
    .family<Transaction, String>((ref, transactionId) async {
  final useCase = getIt<GetTransactionById>();
  final result = await useCase(GetTransactionByIdParams(id: transactionId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (transaction) => transaction,
  );
});

/// Transaction success screen shown after completing a payment
///
/// Displays:
/// - Success icon and message
/// - Transaction number
/// - Total and change amount
/// - "Lihat Struk" button (navigates to transaction detail)
/// - "Transaksi Baru" button (returns to POS)
class TransactionSuccessScreen extends ConsumerWidget {
  const TransactionSuccessScreen({
    super.key,
    required this.transactionId,
  });

  /// The ID of the completed transaction
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(transactionByIdProvider(transactionId));

    return Scaffold(
      body: SafeArea(
        child: transactionAsync.when(
          loading: () => const Center(child: ModernLoading()),
          error: (error, _) => Center(
            child: ModernErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(transactionByIdProvider(transactionId)),
            ),
          ),
          data: (transaction) => _buildContent(context, transaction),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Transaction transaction) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing24),
      child: Column(
        children: [
          // Close button at top-right
          Align(
            alignment: Alignment.topRight,
            child: ModernIconButton(
              icon: Icons.close,
              onPressed: () => context.go('/pos'),
            ),
          ),
          const Spacer(),
          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing24),
          // Success message
          Text(
            'Pembayaran Berhasil!',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'Transaksi telah selesai',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing32),
          // Transaction details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            child: Column(
              children: [
                // Transaction number
                Text(
                  transaction.transactionNumber,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                const ModernDivider(),
                const SizedBox(height: AppDimensions.spacing16),
                // Total
                _buildDetailRow(
                  label: 'Total',
                  value: CurrencyFormatter.format(transaction.total),
                  isHighlighted: true,
                ),
                const SizedBox(height: AppDimensions.spacing12),
                // Cash received
                _buildDetailRow(
                  label: 'Uang Diterima',
                  value: CurrencyFormatter.format(transaction.cashReceived ?? 0),
                ),
                const SizedBox(height: AppDimensions.spacing12),
                // Change
                _buildDetailRow(
                  label: 'Kembalian',
                  value: CurrencyFormatter.format(transaction.cashChange ?? 0),
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: AppDimensions.spacing16),
                const ModernDivider(),
                const SizedBox(height: AppDimensions.spacing12),
                // Item count
                Text(
                  '${transaction.items.length} item',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Action buttons
          Row(
            children: [
              // View receipt button
              Expanded(
                child: ModernButton.outline(
                  onPressed: () {
                    // Navigate to transaction detail (placeholder)
                    context.go('/transactions/$transactionId');
                  },
                  child: const Text('Lihat Struk'),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              // New transaction button
              Expanded(
                child: ModernButton.primary(
                  onPressed: () {
                    // Navigate back to POS screen
                    context.go('/pos');
                  },
                  child: const Text('Transaksi Baru'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isHighlighted = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isHighlighted
              ? AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)
              : AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        Text(
          value,
          style: isHighlighted
              ? AppTextStyles.h4.copyWith(
                  color: valueColor ?? AppColors.primary,
                )
              : AppTextStyles.bodyLarge.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
        ),
      ],
    );
  }
}
