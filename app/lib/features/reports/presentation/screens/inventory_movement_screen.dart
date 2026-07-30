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
import '../widgets/report_layout.dart';

/// Which slice of the movement data is on screen.
enum _MovementView { turnover, slowMoving }

/// Inventory turnover and slow-moving stock, both derived from one payload.
class InventoryMovementScreen extends ConsumerStatefulWidget {
  const InventoryMovementScreen({super.key});

  @override
  ConsumerState<InventoryMovementScreen> createState() =>
      _InventoryMovementScreenState();
}

/// Rows rendered before the reader has to ask for more.
///
/// This screen is one long `SingleChildScrollView`, and both of its forms build
/// eagerly - the table because `shrinkWrap: true` hands its `ListView` a
/// viewport as tall as every row it has, the card form because it is a plain
/// `Column`. So all 500 rows the RPC can return were built and held in the
/// tree on every visit, which is where the jank came from: the fetch is a few
/// milliseconds, the 500 rows are not.
///
/// Capping what is rendered fixes that without changing what is fetched, and
/// keeps the "read it top to bottom" shape a report wants.
const int _renderPageSize = 50;

class _InventoryMovementScreenState
    extends ConsumerState<InventoryMovementScreen> {
  _MovementView _view = _MovementView.turnover;

  int _visibleCount = _renderPageSize;

  void _setView(_MovementView view) {
    setState(() {
      _view = view;
      // The two views are different lists; carrying a depth from one into the
      // other would drop the reader into the middle of a list they have not
      // seen the top of.
      _visibleCount = _renderPageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final movementAsync = ref.watch(productMovementProvider);

    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Pergerakan Stok',
        onProfileTap: () {},
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(productMovementProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: AppDimensions.spacing16,
            bottom: AppDimensions.spacing32 + context.shellBottomInset,
          ),
          child: ModernContentColumn(
            width: ContentWidth.wide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DateRangeSelector(padding: EdgeInsets.zero),
                const SizedBox(height: AppDimensions.spacing16),
                _buildViewToggle(),
                const SizedBox(height: AppDimensions.spacing16),
                movementAsync.when(
                  data: _buildContent,
                  loading: () => const SizedBox(
                    height: 240,
                    child: Center(child: ModernLoading()),
                  ),
                  error: (error, _) => ModernErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(productMovementProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      children: [
        ModernChip(
          label: 'Perputaran',
          selected: _view == _MovementView.turnover,
          onSelected: (_) => _setView(_MovementView.turnover),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        ModernChip(
          label: 'Kurang Laku',
          selected: _view == _MovementView.slowMoving,
          onSelected: (_) => _setView(_MovementView.slowMoving),
        ),
      ],
    );
  }

  Widget _buildContent(List<ProductMovement> movements) {
    if (movements.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum Ada Produk Aktif',
        message: 'Tambahkan produk untuk melihat laporan pergerakan stok.',
      );
    }

    final isSlowView = _view == _MovementView.slowMoving;
    final matching =
        isSlowView ? movements.slowMoving : movements.byTurnoverDesc;

    // Only this slice is built. `matching` stays whole so the footer can say
    // how much of it is on screen.
    final visible = matching.take(_visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportTileGrid(
          minTileWidth: 160,
          maxColumns: 3,
          children: [
            _SummaryTile(
              label: 'Nilai Stok',
              value: CurrencyFormatter.formatCompact(
                movements.totalStockValue,
              ),
              color: AppColors.primary,
            ),
            _SummaryTile(
              label: 'Modal Tertahan',
              value: CurrencyFormatter.formatCompact(
                movements.tiedUpCapital,
              ),
              color: AppColors.warning,
            ),
            _SummaryTile(
              label: 'Tidak Laku',
              value: '${movements.deadStock.length}',
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing24),
        ModernSectionHeader(
          title: isSlowView ? 'Produk Kurang Laku' : 'Perputaran Tercepat',
          subtitle: isSlowView
              ? 'Stok menumpuk atau tidak terjual pada periode ini'
              : 'Rasio perputaran terhadap nilai stok saat ini',
        ),
        const SizedBox(height: AppDimensions.spacing12),
        if (visible.isEmpty)
          const ModernEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Semua Produk Bergerak',
            message: 'Tidak ada produk yang menumpuk pada periode ini.',
          )
        else ...[
          if (context.isAtLeast(Breakpoint.expanded))
            _buildMovementTable(visible, isSlowView)
          else
            Column(
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
          ReportLoadMoreFooter(
            shown: visible.length,
            itemLabel: 'produk',
            // The RPC caps itself at 500, so a full payload means the report
            // stopped counting rather than the shop running out of products.
            atServerLimit: movements.length >= productMovementFetchLimit,
            onLoadMore: visible.length < matching.length
                ? () => setState(
                      () => _visibleCount += _renderPageSize,
                    )
                : null,
          ),
        ],
      ],
    );
  }

  /// The expanded-and-up form: the same six figures per product, aligned in
  /// columns instead of repeated inside a card.
  ///
  /// `shrinkWrap` because the whole screen is one scroll view - a table with
  /// its own scroller nested inside would trap the wheel.
  Widget _buildMovementTable(List<ProductMovement> movements, bool isSlowView) {
    return ModernDataTable<ProductMovement>(
      items: movements,
      idGetter: (movement) => movement.id,
      showCheckboxColumn: false,
      shrinkWrap: true,
      rowHeight: 64,
      narrowBuilder: (context, movement, _) => ProductMovementTile(
        movement: movement,
        showTurnover: !isSlowView,
      ),
      columns: [
        ModernTableColumn<ProductMovement>(
          id: 'name',
          header: const Text('Produk'),
          flex: 3,
          minWidth: 180,
          cellBuilder: (movement) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                movement.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                movement.sku,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ModernTableColumn<ProductMovement>(
          // Sized for the longest badge ("Tidak Laku" is 138dp) plus the cell
          // padding, since a badge does not shrink to fit its column.
          id: 'status',
          header: const Text('Status'),
          width: 168,
          cellBuilder: _statusBadge,
        ),
        ModernTableColumn<ProductMovement>(
          id: 'sold',
          header: const Text('Terjual'),
          width: 92,
          alignment: Alignment.centerRight,
          cellBuilder: (movement) => Text('${movement.quantitySold}'),
        ),
        ModernTableColumn<ProductMovement>(
          id: 'stock',
          header: const Text('Stok'),
          width: 84,
          alignment: Alignment.centerRight,
          cellBuilder: (movement) => Text(
            '${movement.currentStock}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: movement.isOutOfStock ? AppColors.error : null,
            ),
          ),
        ),
        // The two views ask different questions of the same rows, so the last
        // two columns follow the toggle rather than showing everything at once.
        if (!isSlowView) ...[
          ModernTableColumn<ProductMovement>(
            id: 'turnover',
            header: const Text('Perputaran'),
            width: 116,
            alignment: Alignment.centerRight,
            cellBuilder: (movement) => Text(
              movement.turnoverRatio == null
                  ? '-'
                  : '${movement.turnoverRatio!.toStringAsFixed(2)}x',
            ),
          ),
          ModernTableColumn<ProductMovement>(
            id: 'profit',
            header: const Text('Laba'),
            width: 124,
            alignment: Alignment.centerRight,
            cellBuilder: (movement) => Text(
              CurrencyFormatter.formatCompact(movement.totalProfit),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ] else ...[
          ModernTableColumn<ProductMovement>(
            id: 'stockValue',
            header: const Text('Nilai Stok'),
            width: 124,
            alignment: Alignment.centerRight,
            cellBuilder: (movement) => Text(
              CurrencyFormatter.formatCompact(movement.stockValue),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
          ModernTableColumn<ProductMovement>(
            id: 'supply',
            header: const Text('Cukup'),
            width: 100,
            alignment: Alignment.centerRight,
            cellBuilder: (movement) => Text(_daysOfSupplyLabel(movement)),
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(ProductMovement movement) {
    if (movement.isDeadStock) {
      return const ModernBadge.error(label: 'Tidak Laku');
    }
    if (movement.isSlowMoving) {
      return const ModernBadge.warning(label: 'Lambat');
    }
    if (movement.isOutOfStock) {
      return const ModernBadge.neutral(label: 'Stok Habis');
    }
    return const ModernBadge.success(label: 'Lancar');
  }

  String _daysOfSupplyLabel(ProductMovement movement) {
    final days = movement.daysOfSupply;
    if (days == null) return '-';
    if (days > 365) return '>1thn';
    return '${days.round()} hr';
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
