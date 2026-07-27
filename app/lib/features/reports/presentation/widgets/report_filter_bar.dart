import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/report_filter.dart';
import '../providers/report_filter_provider.dart';

/// Category and payment-method filters for the report screens.
///
/// Shows a disclaimer when a category filter is active: the backend then
/// reports line-item revenue rather than transaction totals, so the number is
/// not comparable with the unfiltered one. Saying so beats quietly showing a
/// smaller total that looks like lost sales.
class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => ModernDropdown<String?>(
                  label: 'Kategori',
                  value: filter.categoryId,
                  hint: 'Semua Kategori',
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Semua Kategori'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => ref
                      .read(reportFilterProvider.notifier)
                      .setCategory(value),
                ),
                // Categories failing to load must not block the payment filter,
                // so fall back to a disabled control rather than an error state.
                loading: () => const ModernDropdown<String?>(
                  label: 'Kategori',
                  hint: 'Memuat...',
                  items: [],
                  onChanged: _ignoreChange,
                  enabled: false,
                ),
                error: (_, __) => const ModernDropdown<String?>(
                  label: 'Kategori',
                  hint: 'Gagal memuat',
                  items: [],
                  onChanged: _ignoreChange,
                  enabled: false,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: ModernDropdown<PaymentMethod?>(
                label: 'Pembayaran',
                value: filter.paymentMethod,
                hint: 'Semua Metode',
                items: [
                  const DropdownMenuItem<PaymentMethod?>(
                    value: null,
                    child: Text('Semua Metode'),
                  ),
                  ...PaymentMethod.values.map(
                    (method) => DropdownMenuItem<PaymentMethod?>(
                      value: method,
                      child: Text(method.label),
                    ),
                  ),
                ],
                onChanged: (value) => ref
                    .read(reportFilterProvider.notifier)
                    .setPaymentMethod(value),
              ),
            ),
          ],
        ),
        if (filter.isActive) ...[
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: filter.hasCategoryFilter
                    ? Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppDimensions.spacing4),
                          Expanded(
                            child: Text(
                              'Total dihitung dari item kategori ini, '
                              'belum termasuk diskon transaksi',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              ModernButton.text(
                onPressed: () =>
                    ref.read(reportFilterProvider.notifier).clear(),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Placeholder handler for the disabled dropdown states, which cannot emit a
/// change but still need a non-null callback.
void _ignoreChange(Object? _) {}
