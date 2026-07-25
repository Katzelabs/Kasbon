import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/services/image_storage/image_storage_service.dart';
import '../../../../shared/modern/modern.dart';
import 'product_image.dart';

/// Widget for picking and displaying product images.
/// Handles camera/gallery selection, compression, and storage.
class ProductImagePicker extends StatefulWidget {
  const ProductImagePicker({
    super.key,
    this.currentImagePath,
    required this.productId,
    required this.onImageChanged,
    this.size = 120,
  });

  /// Current image path (if editing existing product)
  final String? currentImagePath;

  /// Product ID for image naming
  final String productId;

  /// Callback when image is changed (path or null if removed)
  final ValueChanged<String?> onImageChanged;

  /// Size of the image preview
  final double size;

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ImagePicker _picker = ImagePicker();
  final ImageStorageService _imageService = getIt<ImageStorageService>();

  String? _imagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.currentImagePath;
  }

  @override
  void didUpdateWidget(ProductImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImagePath != widget.currentImagePath) {
      setState(() {
        _imagePath = widget.currentImagePath;
      });
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      builder: (context) => _buildSourceSheet(),
    );
  }

  Widget _buildSourceSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            const Text(
              'Pilih Sumber Foto',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing24),
            _buildSourceOption(
              icon: Icons.camera_alt_outlined,
              label: 'Kamera',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: AppDimensions.spacing12),
            _buildSourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Galeri',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null) ...[
              const SizedBox(height: AppDimensions.spacing12),
              _buildSourceOption(
                icon: Icons.delete_outline,
                label: 'Hapus Foto',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            ],
            const SizedBox(height: AppDimensions.spacing8),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppDimensions.spacing12),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check and request permission
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            _showPermissionDeniedDialog('kamera');
          }
          return;
        }
      }

      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Delete old image if exists
      if (_imagePath != null) {
        try {
          await _imageService.deleteImage(_imagePath!);
        } catch (_) {
          // Ignore errors when deleting old image
        }
      }

      // Save and compress the new image
      final savedPath = await _imageService.saveImage(
        File(pickedFile.path),
        widget.productId,
      );

      setState(() {
        _imagePath = savedPath;
        _isLoading = false;
      });

      widget.onImageChanged(savedPath);
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ModernToast.error(
          context,
          'Gagal memproses gambar: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _removeImage() async {
    if (_imagePath == null) return;

    try {
      await _imageService.deleteImage(_imagePath!);
    } catch (_) {
      // Ignore errors when deleting
    }

    setState(() => _imagePath = null);
    widget.onImageChanged(null);
  }

  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: Text(
          'Untuk menggunakan fitur ini, aplikasi memerlukan akses $permissionName. '
          'Silakan berikan izin melalui pengaturan perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceSheet,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or Placeholder
              if (_imagePath != null && !_isLoading)
                ProductImage(
                  imagePath: _imagePath,
                  size: widget.size,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium - 1),
                )
              else if (!_isLoading)
                _buildPlaceholder(),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  child: const Center(
                    child: ModernLoading(),
                  ),
                ),

              // Camera icon overlay (when not loading)
              if (!_isLoading)
                Positioned(
                  right: AppDimensions.spacing8,
                  bottom: AppDimensions.spacing8,
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: widget.size * 0.3,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            'Tambah Foto',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
