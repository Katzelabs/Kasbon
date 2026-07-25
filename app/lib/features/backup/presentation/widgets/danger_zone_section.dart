import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// Section for dangerous operations like clearing all data
class DangerZoneSection extends StatelessWidget {
  final VoidCallback onClearAllData;

  const DangerZoneSection({
    super.key,
    required this.onClearAllData,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      borderColor: AppColors.error.withValues(alpha: 0.3),
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
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona Berbahaya',
                      style: AppTextStyles.h4,
                    ),
                    Text(
                      'Tindakan berisiko tinggi',
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

          // Description
          Text(
            'Hapus semua data aplikasi termasuk produk, transaksi, kategori, dan pengaturan. Data yang dihapus tidak dapat dikembalikan.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.spacing16),

          // Clear All Data Button
          ModernButton.destructive(
            onPressed: onClearAllData,
            fullWidth: true,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever_rounded, size: 20),
                SizedBox(width: AppDimensions.spacing8),
                Text('Hapus Semua Data'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
