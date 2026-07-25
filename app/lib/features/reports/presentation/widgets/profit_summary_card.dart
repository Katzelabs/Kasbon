import 'package:flutter/material.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/profit_summary.dart';

/// Card displaying profit summary for a period
class ProfitSummaryCard extends StatelessWidget {
  final ProfitSummary summary;
  final String title;
  final VoidCallback? onTap;

  const ProfitSummaryCard({
    super.key,
    required this.summary,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernGradientCard.success(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Main profit figure
              Text(
                CurrencyFormatter.format(summary.totalProfit),
                style: AppTextStyles.priceLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: AppDimensions.spacing8),

              // Margin percentage
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing8,
                  vertical: AppDimensions.spacing4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  'Margin ${summary.profitMargin.toStringAsFixed(1)}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacing16),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    label: 'Total Penjualan',
                    value: CurrencyFormatter.format(summary.totalSales),
                  ),
                  _buildStatItem(
                    label: 'Transaksi',
                    value: summary.transactionCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
