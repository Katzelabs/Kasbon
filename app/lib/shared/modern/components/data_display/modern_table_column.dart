import 'package:flutter/material.dart';

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
  static ModernTableColumn<T> image<T>({
    required String id,
    required String? Function(T item) imageUrlGetter,
    double size = 40.0,
    Widget? placeholder,
    BorderRadius? borderRadius,
  }) {
    return ModernTableColumn<T>(
      id: id,
      header: const SizedBox.shrink(),
      width: size + 16,
      alignment: Alignment.center,
      cellBuilder: (item) {
        final imageUrl = imageUrlGetter(item);
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(4),
          child: SizedBox(
            width: size,
            height: size,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        placeholder ??
                        Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: size * 0.5,
                            color: Colors.grey[400],
                          ),
                        ),
                  )
                : placeholder ??
                    Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_outlined,
                        size: size * 0.5,
                        color: Colors.grey[400],
                      ),
                    ),
          ),
        );
      },
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
