import 'package:flutter/material.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../core/services/image_storage/image_storage_service.dart';
import '../../../../core/widgets/adaptive_local_image.dart';
import '../../../../shared/modern/modern.dart';

/// Whether [reference] is a path on this device rather than in the bucket.
///
/// Legacy data: rows written by the retired local storage. No new ones are
/// created, and they were never valid anywhere but the phone that took the
/// photo.
bool isLocalImageFile(String reference) =>
    reference.startsWith('/') || reference.startsWith('file://');

/// The URL that renders a stored `products.image_url` [reference].
///
/// A row holds the object's path inside the bucket, so the host is not in the
/// data - which is the whole point, since it differs between a browser
/// (`127.0.0.1`), the Android emulator (`10.0.2.2`), a LAN device and
/// production. Every render site resolves through here rather than handing
/// `image_url` to `Image.network` and hoping the environment matches whichever
/// one wrote the row.
///
/// The reference comes back unchanged if the storage service is not available -
/// only true in a widget test that never registered one, where the value is
/// already an absolute URL or nothing renders either way.
String productImageUrl(String reference) {
  if (!getIt.isRegistered<ImageStorageService>()) return reference;
  return getIt<ImageStorageService>().publicUrlFor(reference);
}

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
  bool get _isLocalFile =>
      imagePath != null && isLocalImageFile(imagePath!);

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

    // Everything else is a reference into the bucket - a path, or one of the
    // full URLs stored before paths were. This used to fall back to a local
    // file for anything it could not recognise as `http`, which is exactly what
    // an object path looks like.
    return _buildNetworkImage(iconSize);
  }

  Widget _buildLocalImage(double iconSize) {
    return AdaptiveLocalImage(
      path: imagePath!,
      fit: fit,
      fallback: (_) => _buildPlaceholder(iconSize),
    );
  }

  Widget _buildNetworkImage(double iconSize) {
    return Image.network(
      productImageUrl(imagePath!),
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholder(iconSize),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: ModernLoading.small(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
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
