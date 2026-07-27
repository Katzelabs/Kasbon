import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/modern/modern.dart';
import '../../domain/entities/product_movement.dart';
import '../providers/analytics_provider.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/product_movement_tile.dart';

/// Which slice of the movement data is on screen.
enum _MovementView { turnover, slowMoving }

/// Inventory turnover and slow-moving stock, both derived from one payload.
class InventoryMovementScreen extends ConsumerStatefulWidget {
  const InventoryMovementScreen({super.key});

  @override
  ConsumerState<InventoryMovementScreen> createState() =>
      _InventoryMovementScreenState();
}

class _InventoryMovementScreenState
    extends ConsumerState<InventoryMovementScreen> {
  _MovementView _view = _MovementView.turnover;

  @override
  Widget build(BuildContext context) {
    final movementAsync = ref.watch(productMovementProvider);
    final bottomPadding =
        AppDimensions.spacing16 + context.shellBottomInset;

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Pergerakan Stok',
        onProfileTap: () {},
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(productMovementProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spacing16),
              const DateRangeSelector(),
              const SizedBox(height: AppDimensions.spacing16),
              _buildViewToggle(),
              const SizedBox(height: AppDimensions.spacing16),
              movementAsync.when(
                data: _buildContent,
                loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: ModernLoading()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing16,
                  ),
                  child: ModernErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(productMovementProvider),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Row(
        children: [
          ModernChip(
            label: 'Perputaran',
            selected: _view == _MovementView.turnover,
            onSelected: (_) => setState(() => _view = _MovementView.turnover),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          ModernChip(
            label: 'Kurang Laku',
            selected: _view == _MovementView.slowMoving,
            onSelected: (_) => setState(() => _view = _MovementView.slowMoving),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<ProductMovement> movements) {
    if (movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
        child: ModernEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Belum Ada Produk Aktif',
          message: 'Tambahkan produk untuk melihat laporan pergerakan stok.',
        ),
      );
    }

    final isSlowView = _view == _MovementView.slowMoving;
    final visible =
        isSlowView ? movements.slowMoving : movements.byTurnoverDesc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Nilai Stok',
                  value: CurrencyFormatter.formatCompact(
                    movements.totalStockValue,
                  ),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _SummaryTile(
                  label: 'Modal Tertahan',
                  value: CurrencyFormatter.formatCompact(
                    movements.tiedUpCapital,
                  ),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _SummaryTile(
                  label: 'Tidak Laku',
                  value: '${movements.deadStock.length}',
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing24),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: ModernSectionHeader(
            title: isSlowView ? 'Produk Kurang Laku' : 'Perputaran Tercepat',
            subtitle: isSlowView
                ? 'Stok menumpuk atau tidak terjual pada periode ini'
                : 'Rasio perputaran terhadap nilai stok saat ini',
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
            child: ModernEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Semua Produk Bergerak',
              message: 'Tidak ada produk yang menumpuk pada periode ini.',
            ),
          )
        else
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
            child: Column(
              children: [
                for (final movement in visible)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimensions.spacing12),
                    child: ProductMovementTile(
                      movement: movement,
                      showTurnover: !isSlowView,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.filled(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
