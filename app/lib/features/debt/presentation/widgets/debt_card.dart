import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../providers/debt_provider.dart';

/// Card widget for displaying individual debt transaction
class DebtCard extends ConsumerWidget {
  const DebtCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onMarkPaid,
  });

  /// The debt transaction to display
  final Transaction transaction;

  /// Callback when card is tapped (e.g., view details)
  final VoidCallback? onTap;

  /// Callback when mark as paid is tapped
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markPaidState = ref.watch(markDebtPaidProvider);

    return ModernCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Transaction number and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                transaction.transactionNumber,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormatter.getRelativeTime(transaction.transactionDate),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(transaction.total),
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const ModernBadge.warning(label: 'Hutang'),
            ],
          ),

          // Notes (if present)
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              transaction.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppDimensions.spacing12),

          // Mark as paid button
          Align(
            alignment: Alignment.centerRight,
            child: ModernButton.outline(
              size: ModernSize.small,
              isLoading: markPaidState.isLoading,
              leadingIcon: Icons.check_circle_outline,
              onPressed: onMarkPaid,
              child: const Text('Tandai Lunas'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version of debt card for list view
class DebtCardCompact extends StatelessWidget {
  const DebtCardCompact({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ModernListTile(
      onTap: onTap,
      title: Text(transaction.transactionNumber),
      subtitle: Text(DateFormatter.getRelativeTime(transaction.transactionDate)),
      trailing: Text(
        CurrencyFormatter.format(transaction.total),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
