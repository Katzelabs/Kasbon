import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';

/// Definition for a single table column in ModernDataTable
///
/// Example usage:
/// ```dart
/// ModernTableColumn<Product>(
///   id: 'name',
///   header: const Text('Nama Produk'),
///   cellBuilder: (product) => Text(product.name),
///   flex: 2,
/// )
/// ```
class ModernTableColumn<T> {
  const ModernTableColumn({
    required this.id,
    required this.header,
    required this.cellBuilder,
    this.width,
    this.flex,
    this.minWidth = 80.0,
    this.maxWidth,
    this.alignment = Alignment.centerLeft,
    this.headerAlignment,
    this.padding,
    this.sortable = false,
  });

  /// Unique identifier for this column
  final String id;

  /// Header widget (typically Text)
  final Widget header;

  /// Builder for cell content given an item
  final Widget Function(T item) cellBuilder;

  /// Fixed width (overrides flex if set)
  final double? width;

  /// Flex factor for dynamic sizing (used when width is null)
  final int? flex;

  /// Minimum width when using flex
  final double minWidth;

  /// Maximum width when using flex
  final double? maxWidth;

  /// Cell content alignment
  final Alignment alignment;

  /// Header alignment (defaults to cell alignment if not specified)
  final Alignment? headerAlignment;

  /// Custom padding for cells in this column
  final EdgeInsetsGeometry? padding;

  /// Whether this column's header offers a sort control.
  ///
  /// Marking a column sortable does nothing on its own - the table also needs
  /// an `onSort` callback, because sorting is the caller's data operation and
  /// not something a presentation widget can do to a list it was handed.
  final bool sortable;

  /// Get effective header alignment
  Alignment get effectiveHeaderAlignment => headerAlignment ?? alignment;

  /// Get effective width considering flex and constraints
  double getEffectiveWidth(double availableWidth, int totalFlex) {
    if (width != null) return width!;
    if (flex != null && totalFlex > 0) {
      final flexWidth = (availableWidth * flex!) / totalFlex;
      return flexWidth.clamp(minWidth, maxWidth ?? double.infinity);
    }
    return minWidth;
  }
}

/// Extension with convenience factory constructors for common column types
extension ModernTableColumnFactories<T> on ModernTableColumn<T> {
  /// Creates a column for displaying text
  static ModernTableColumn<T> text<T>({
    required String id,
    required String headerText,
    required String Function(T item) valueGetter,
    double? width,
    int? flex,
    Alignment alignment = Alignment.centerLeft,
    TextStyle? textStyle,
    int maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return ModernTableColumn<T>(
      id: id,
      header: Text(headerText),
      width: width,
      flex: flex,
      alignment: alignment,
      cellBuilder: (item) => Text(
        valueGetter(item),
        style: textStyle,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  /// Creates a column for displaying images/avatars
  ///
  /// Takes the image *widget* for a row, not a URL. It used to take a
  /// `imageUrlGetter` and call `Image.network` on whatever came back, which is
  /// wrong in this library twice over. A stored image reference is not
  /// necessarily a URL - `products.image_url` holds an object path inside a
  /// storage bucket, and resolving it needs a host this component has no
  /// business knowing - and the loading, error and legacy-path handling a photo
  /// needs already exists in the feature widgets. So the caller passes
  /// `ProductImage(...)`, or whatever its equivalent is, and this column does
  /// what a column can: reserve the width, centre it, clip the corners.
  ///
  /// Returning null from [imageBuilder] means the row has no image, and gets
  /// [placeholder].
  static ModernTableColumn<T> image<T>({
    required String id,
    required Widget? Function(T item) imageBuilder,
    double size = 40.0,
    Widget? placeholder,
    BorderRadius? borderRadius,
  }) {
    return ModernTableColumn<T>(
      id: id,
      header: const SizedBox.shrink(),
      width: size + AppDimensions.spacing16,
      alignment: Alignment.center,
      cellBuilder: (item) => ClipRRect(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppDimensions.radiusSmall),
        child: SizedBox(
          width: size,
          height: size,
          child: imageBuilder(item) ??
              placeholder ??
              _ImageCellPlaceholder(size: size),
        ),
      ),
    );
  }

  /// Creates a column for action buttons
  static ModernTableColumn<T> actions<T>({
    required String id,
    required List<Widget> Function(T item) actionsBuilder,
    double width = 80.0,
  }) {
    return ModernTableColumn<T>(
      id: id,
      header: const SizedBox.shrink(),
      width: width,
      alignment: Alignment.center,
      cellBuilder: (item) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: actionsBuilder(item),
      ),
    );
  }
}

/// What an image cell shows for a row with no image.
class _ImageCellPlaceholder extends StatelessWidget {
  const _ImageCellPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.5,
        color: AppColors.textTertiary,
      ),
    );
  }
}
