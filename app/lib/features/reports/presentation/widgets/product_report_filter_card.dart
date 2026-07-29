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
      // Sized to its content so it can sit in a toolbar beside the date chips
      // rather than only ever spanning a screen of its own.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sort label
        Text(
          'Urutkan:',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        // Flexible so the control gives way to the label rather than
        // overflowing: on a 375dp phone "Urutkan:" plus a 240dp dropdown is
        // 7dp more than the gutter leaves. Callers must therefore hand this
        // widget bounded width - the toolbar does so with a ConstrainedBox.
        Flexible(child: _buildSortDropdown(ref, filter.sortOption)),
      ],
    );
  }

  Widget _buildSortDropdown(
    WidgetRef ref,
    ProductReportSortOption selectedOption,
  ) {
    return Container(
      height: 44,
      // Bounded so `isExpanded` has something to expand into: the control sits
      // in a toolbar row where its parent hands it unbounded width, and the
      // longest option ("Margin Terbaik" and friends) is wider than a 375dp
      // phone leaves beside the "Urutkan:" label.
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductReportSortOption>(
          value: selectedOption,
          isExpanded: true,
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
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(productReportFilterProvider.notifier)
                  .setSortOption(value);
            }
          },
        ),
      ),
    );
  }
}
