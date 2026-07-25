import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../domain/entities/product_report_filter.dart';
import '../providers/product_report_filter_provider.dart';

/// Sort dropdown widget for product report
class ProductReportFilterCard extends ConsumerWidget {
  const ProductReportFilterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productReportFilterProvider);

    return Row(
      children: [
        // Sort label
        Text(
          'Urutkan:',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        // Sort dropdown
        _buildSortDropdown(ref, filter.sortOption),
      ],
    );
  }

  Widget _buildSortDropdown(
    WidgetRef ref,
    ProductReportSortOption selectedOption,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductReportSortOption>(
          value: selectedOption,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
          items: ProductReportSortOption.values.map((option) {
            return DropdownMenuItem<ProductReportSortOption>(
              value: option,
              child: Text(option.label),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(productReportFilterProvider.notifier).setSortOption(value);
            }
          },
        ),
      ),
    );
  }
}
