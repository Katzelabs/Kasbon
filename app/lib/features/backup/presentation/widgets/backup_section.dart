import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/backup_provider.dart';

/// Section for creating backups
class BackupSection extends ConsumerWidget {
  final bool isCreatingBackup;
  final VoidCallback onCreateBackup;

  const BackupSection({
    super.key,
    required this.isCreatingBackup,
    required this.onCreateBackup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataCountsAsync = ref.watch(dataCountsProvider);
    final lastBackupAsync = ref.watch(lastBackupProvider);

    return ModernCard.elevated(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: const Icon(
                  Icons.backup_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup Data',
                      style: AppTextStyles.h4,
                    ),
                    Text(
                      'Simpan salinan data ke file',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing16),
          const ModernDivider(),
          const SizedBox(height: AppDimensions.spacing16),

          // Data Counts
          dataCountsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
                child: ModernLoading.small(),
              ),
            ),
            error: (error, _) => Text(
              'Gagal memuat data',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            data: (counts) => Column(
              children: [
                _buildCountRow('Produk', counts.products),
                const SizedBox(height: AppDimensions.spacing8),
                _buildCountRow('Transaksi', counts.transactions),
                const SizedBox(height: AppDimensions.spacing8),
                _buildCountRow('Kategori', counts.categories),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Create Backup Button
          ModernButton.primary(
            onPressed: isCreatingBackup ? null : onCreateBackup,
            isLoading: isCreatingBackup,
            fullWidth: true,
            child: const Text('Buat Backup'),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Last Backup Info
          lastBackupAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (metadata) {
              if (metadata == null) {
                return Text(
                  'Belum pernah membuat backup',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
              return Container(
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.spacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup terakhir',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            dateFormat.format(metadata.backupDate),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      metadata.formattedFileSize,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          count.toString(),
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
