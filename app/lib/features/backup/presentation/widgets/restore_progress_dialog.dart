import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/backup_provider.dart';

/// Non-dismissible dialog showing restore progress
class RestoreProgressDialog extends ConsumerWidget {
  const RestoreProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupState = ref.watch(backupProvider);

    return PopScope(
      canPop: false, // Prevent back button dismiss
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading Animation
              const SizedBox(
                width: 64,
                height: 64,
                child: ModernLoading(),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Title
              const Text(
                'Memulihkan Data...',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacing8),

              // Current Step
              Text(
                backupState.restoreStep ?? 'Mempersiapkan...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                child: LinearProgressIndicator(
                  value: backupState.restoreProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),

              const SizedBox(height: AppDimensions.spacing8),

              // Progress Percentage
              Text(
                '${(backupState.restoreProgress * 100).toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.spacing8),
                    Expanded(
                      child: Text(
                        'Jangan tutup aplikasi',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
