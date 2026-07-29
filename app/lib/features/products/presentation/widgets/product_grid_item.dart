import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/adaptive_local_image.dart';
import '../../../../shared/modern/components/card/modern_card.dart';
import '../../../../shared/modern/utils/modern_hover.dart';
import '../../domain/entities/product.dart';
import 'stock_indicator.dart';

/// A product as a card in the grid: square photo, name, SKU, price and stock.
///
/// ## The card measures itself, and publishes the height it needs
///
/// The grid used to hand every card the same `childAspectRatio`, which is a
/// ratio and therefore says nothing about how much room the *text* needs. At
/// two columns on a phone the block under the photo was cramped; at five
/// columns on a 2560px monitor the same ratio gave 500dp cards with an ocean of
/// white under three lines of type.
///
/// So the sizing runs the other way now. [extentFor] states what a card of a
/// given width actually wants - a square image plus a text block measured from
/// the type it is about to render, at the current text scale - and the grid
/// asks for exactly that via `mainAxisExtent`. Nothing is left to a ratio, and
/// an accessibility text size grows the cards instead of overflowing them.
///
/// Two type scales, picked from the card's own width rather than the window's:
/// the same card appears at ~140dp in a phone's two-up grid and at ~200dp on a
/// desktop, and a single scale cannot serve both.
class ProductGridItem extends StatelessWidget {
  const ProductGridItem({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final Product product;
  final VoidCallback onTap;

  /// Callback when item is long-pressed (used to enter selection mode)
  final VoidCallback? onLongPress;

  /// Whether selection mode is active (shows checkbox overlay)
  final bool isSelectionMode;

  /// Whether this item is currently selected
  final bool isSelected;

  /// The width at which a card switches to its roomy type scale.
  ///
  /// Below this the card is one of two on a phone; above it there is room for
  /// the larger name and price a pointer-sized card can carry.
  static const double roomyWidth = 176;

  // Type metrics. Held here rather than read off AppTextStyles because
  // [infoHeight] has to do arithmetic on them before anything is laid out, and
  // a size the height calculation and the Text widget do not share is a card
  // that overflows by exactly the difference.
  static const double _nameSizeRoomy = 14;
  static const double _nameSizeTight = 12.5;
  static const double _nameHeight = 1.25;
  static const double _skuSize = 10.5;
  static const double _skuHeight = 1.3;
  static const double _priceSizeRoomy = 15;
  static const double _priceSizeTight = 13;
  static const double _priceHeight = 1.25;

  /// The stock pill's label, which sets a floor under the bottom row.
  static const double _stockPillTextSize = 11;
  static const double _stockPillPadding = 8;

  /// A couple of pixels of slack, so a font whose metrics round up a hair does
  /// not turn into a yellow-and-black overflow stripe.
  static const double _slack = 2;

  /// Height the text block under the photo needs on a card [tileWidth] wide.
  static double infoHeight(BuildContext context, double tileWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final roomy = tileWidth >= roomyWidth;
    final padding = roomy ? AppDimensions.spacing12 : AppDimensions.spacing8;

    // Two lines of name, always - a one-line name still reserves the second so
    // that neighbouring cards line their prices up.
    final name =
        scaler.scale(roomy ? _nameSizeRoomy : _nameSizeTight) * _nameHeight * 2;
    final sku = scaler.scale(_skuSize) * _skuHeight;
    final bottomRow = math.max(
      scaler.scale(roomy ? _priceSizeRoomy : _priceSizeTight) * _priceHeight,
      scaler.scale(_stockPillTextSize) * _skuHeight + _stockPillPadding,
    );

    return padding * 2 +
        name +
        AppDimensions.spacing2 +
        sku +
        AppDimensions.spacing8 +
        bottomRow +
        _slack;
  }

  /// Total height a card [tileWidth] wide wants: the square photo plus its text.
  static double extentFor(BuildContext context, double tileWidth) =>
      tileWidth + infoHeight(context, tileWidth);

  @override
  Widget build(BuildContext context) {
    // Whether this product is the one open in the detail pane beside the list.
    // Null outside a split view, so a phone never lights a card up.
    final isOpen = MasterSelectionScope.selectedIdOf(context) == product.id;
    final isHighlighted = isSelected || isOpen;

    // The long-press used to hang off a GestureDetector wrapped around the
    // card. ModernCard takes it directly, and going through the card means the
    // press shares one hit region with the tap - and picks up the hover lift
    // and pointer cursor that a bare GestureDetector cannot provide.
    return ModernCard.outlined(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      // Tinted rather than merely outlined: at two cards across, a border
      // colour alone is easy to miss against the card next to it.
      color: isOpen ? AppColors.primaryContainer : null,
      borderColor: isHighlighted ? AppColors.primary : AppColors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy = constraints.maxWidth >= roomyWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Square, and full-bleed: the card clips to its own radius, so
              // the photo needs no rounding of its own.
              AspectRatio(
                aspectRatio: 1,
                child: _buildPhoto(),
              ),
              Expanded(child: _buildInfo(roomy)),
            ],
          );
        },
      ),
    );
  }

  /// The photo, its status pill, and the selection checkbox.
  Widget _buildPhoto() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.surfaceVariant,
          // A slow zoom under the pointer, contained by the card's clip. The
          // card's own lift says "clickable"; this says "this one".
          child: ModernHoverBuilder(
            child: _buildImage(),
            builder: (context, isHovered, child) => AnimatedScale(
              scale: isHovered ? 1.05 : 1,
              duration: ModernHoverBuilder.duration,
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        ),
        // Out of stock is a state you should be able to read from across the
        // room, so the photo itself goes pale rather than only wearing a badge.
        if (product.isOutOfStock)
          const ColoredBox(color: Color(0x8CFFFFFF)),
        if (product.isOutOfStock || product.isLowStock)
          Positioned(
            top: AppDimensions.spacing8,
            left: AppDimensions.spacing8,
            child: _StockPill(
              label: product.isOutOfStock ? 'Habis' : 'Menipis',
              color: product.isOutOfStock ? AppColors.error : AppColors.warning,
            ),
          ),
        if (isSelectionMode)
          Positioned(
            top: AppDimensions.spacing8,
            right: AppDimensions.spacing8,
            child: _SelectionCheckbox(isSelected: isSelected),
          ),
      ],
    );
  }

  /// Name, SKU, price and stock.
  ///
  /// Laid out against the height [infoHeight] reserved: the name and SKU sit at
  /// the top, the price row is pinned to the bottom edge, and the gap between
  /// them absorbs the difference. Cards in a row therefore align on their price
  /// line whether the name above took one line or two.
  Widget _buildInfo(bool roomy) {
    final padding = roomy ? AppDimensions.spacing12 : AppDimensions.spacing8;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: roomy ? _nameSizeRoomy : _nameSizeTight,
                  height: _nameHeight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacing2),
              Text(
                product.sku,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: _skuSize,
                  height: _skuHeight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  CurrencyFormatter.format(product.sellingPrice),
                  style: AppTextStyles.priceSmall.copyWith(
                    color: AppColors.primary,
                    fontSize: roomy ? _priceSizeRoomy : _priceSizeTight,
                    fontWeight: FontWeight.w700,
                    height: _priceHeight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing4),
              StockIndicator(
                stock: product.stock,
                minStock: product.minStock,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imagePath = product.imageUrl;
    if (imagePath == null || imagePath.isEmpty) return _buildPlaceholderIcon();

    final isLocalFile =
        imagePath.startsWith('/') || imagePath.startsWith('file://');

    if (isLocalFile) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: AdaptiveLocalImage(
          path: imagePath,
          fallback: (_) => _buildPlaceholderIcon(),
        ),
      );
    }

    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
    );
  }

  Widget _buildPlaceholderIcon() {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: AppDimensions.iconXLarge,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// The "Habis" / "Menipis" flag over a photo.
///
/// Solid rather than the tinted badge the rest of the app uses: it sits on top
/// of a photograph, and a 10%-alpha fill disappears over anything but a white
/// product shot.
class _StockPill extends StatelessWidget {
  const _StockPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
          height: 1.2,
        ),
      ),
    );
  }
}

/// The bulk-selection tick in the photo's corner.
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check,
              size: 16,
              color: AppColors.onPrimary,
            )
          : null,
    );
  }
}
