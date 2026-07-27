import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/backup_metadata.dart';

/// Dialog shown after successful backup creation
class BackupSuccessDialog extends StatelessWidget {
  final BackupMetadata metadata;

  const BackupSuccessDialog({
    super.key,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // Title
            const Text(
              'Backup Berhasil!',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.spacing8),

            // Message
            //
            // A browser download has no path the app can name, so on web the
            // wording points at the one place the user can actually look.
            Text(
              metadata.hasFilePath
                  ? 'Data Anda telah disimpan ke file backup.'
                  : 'Berkas backup telah diunduh oleh browser Anda.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.spacing16),

            // File Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Column(
                children: [
                  // Filename
                  Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppDimensions.spacing8),
                      Expanded(
                        child: Text(
                          metadata.fileName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // File size, where the platform can tell us one. A browser
                  // download cannot be stat'ed, and "Ukuran: 0 B" reads as a
                  // failed backup.
                  if (metadata.fileSizeBytes > 0) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    Row(
                      children: [
                        const Icon(
                          Icons.data_usage_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppDimensions.spacing8),
                        Text(
                          'Ukuran: ${metadata.formattedFileSize}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacing24),

            // Buttons
            //
            // Sharing needs a file the system can hand to another app. Where
            // the backup went to the browser's downloads there is no such
            // handle, and the caller ignores a `true` result - so the button
            // is left out rather than offered as a no-op.
            if (metadata.hasFilePath)
              Row(
                children: [
                  Expanded(
                    child: ModernButton.outline(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Selesai'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: ModernButton.primary(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, size: 18),
                          SizedBox(width: AppDimensions.spacing4),
                          Text('Bagikan'),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ModernButton.primary(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Selesai'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
