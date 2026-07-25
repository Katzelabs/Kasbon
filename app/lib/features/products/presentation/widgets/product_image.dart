import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';

/// Widget for displaying product images.
/// Handles local file paths, network URLs, and placeholder fallback.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.imagePath,
    this.size = 56,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.inventory_2_outlined,
    this.placeholderIconSize,
  });

  /// The image path (local file path or network URL)
  final String? imagePath;

  /// Size of the image container (width and height)
  final double size;

  /// How the image should be fitted
  final BoxFit fit;

  /// Border radius for the image container
  final BorderRadius? borderRadius;

  /// Icon to show when no image is available
  final IconData placeholderIcon;

  /// Size of the placeholder icon (defaults to size * 0.5)
  final double? placeholderIconSize;

  /// Check if the path is a local file
  bool get _isLocalFile {
    if (imagePath == null) return false;
    return imagePath!.startsWith('/') || imagePath!.startsWith('file://');
  }

  /// Check if the path is a network URL
  bool get _isNetworkUrl {
    if (imagePath == null) return false;
    return imagePath!.startsWith('http://') ||
        imagePath!.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.radiusSmall);
    final effectiveIconSize = placeholderIconSize ?? (size * 0.5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: effectiveBorderRadius,
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: _buildImage(effectiveIconSize),
      ),
    );
  }

  Widget _buildImage(double iconSize) {
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder(iconSize);
    }

    if (_isLocalFile) {
      return _buildLocalImage(iconSize);
    }

    if (_isNetworkUrl) {
      return _buildNetworkImage(iconSize);
    }

    // Treat as local file path if not recognized
    return _buildLocalImage(iconSize);
  }

  Widget _buildLocalImage(double iconSize) {
    final file = File(imagePath!.replaceFirst('file://', ''));

    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholder(iconSize),
    );
  }

  Widget _buildNetworkImage(double iconSize) {
    return Image.network(
      imagePath!,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholder(iconSize),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: iconSize * 0.6,
            height: iconSize * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(double iconSize) {
    return Center(
      child: Icon(
        placeholderIcon,
        color: AppColors.textTertiary,
        size: iconSize,
      ),
    );
  }
}

/// Extension for ProductImage with common presets
extension ProductImagePresets on ProductImage {
  /// Create a small thumbnail (40x40)
  static ProductImage thumbnail({
    String? imagePath,
    BorderRadius? borderRadius,
  }) {
    return ProductImage(
      imagePath: imagePath,
      size: 40,
      borderRadius: borderRadius,
    );
  }

  /// Create a medium image (56x56) - default list tile size
  static ProductImage medium({
    String? imagePath,
    BorderRadius? borderRadius,
  }) {
    return ProductImage(
      imagePath: imagePath,
      size: 56,
      borderRadius: borderRadius,
    );
  }

  /// Create a large image (80x80)
  static ProductImage large({
    String? imagePath,
    BorderRadius? borderRadius,
  }) {
    return ProductImage(
      imagePath: imagePath,
      size: 80,
      borderRadius: borderRadius,
    );
  }
}
