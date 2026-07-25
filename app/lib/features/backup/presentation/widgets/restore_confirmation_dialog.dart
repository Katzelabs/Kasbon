import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/backup_metadata.dart';

/// Dialog for confirming restore operation
class RestoreConfirmationDialog extends StatelessWidget {
  final BackupInfo backupInfo;

  const RestoreConfirmationDialog({
    super.key,
    required this.backupInfo,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 48,
              ),
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // Title
            const Text(
              'Restore Data?',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // Backup Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Tanggal Backup', dateFormat.format(backupInfo.backupDate)),
                  const SizedBox(height: AppDimensions.spacing8),
                  _buildInfoRow('Produk', '${backupInfo.productsCount}'),
                  const SizedBox(height: AppDimensions.spacing8),
                  _buildInfoRow('Transaksi', '${backupInfo.transactionsCount}'),
                  const SizedBox(height: AppDimensions.spacing8),
                  _buildInfoRow('Kategori', '${backupInfo.categoriesCount}'),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // Warning Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      'Semua data saat ini akan dihapus dan diganti dengan data dari file backup. Tindakan ini tidak dapat dibatalkan.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacing24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ModernButton.outline(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: ModernButton.destructive(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Ya, Restore'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
