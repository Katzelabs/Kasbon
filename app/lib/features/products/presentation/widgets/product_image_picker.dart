import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/di/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/services/image_storage/image_storage_service.dart';
import '../../../../shared/modern/modern.dart';
import 'product_image.dart';

/// Where a product photo can come from.
enum _ImageSourceAction {
  camera('Kamera', Icons.camera_alt_outlined),
  gallery('Galeri', Icons.photo_library_outlined),
  remove('Hapus Foto', Icons.delete_outline);

  const _ImageSourceAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Widget for picking and displaying product images.
/// Handles camera/gallery selection, compression, and storage.
///
/// Uploads, and never deletes. Removing the old object is the form's job, once
/// the row that references it has actually been written - see
/// `ProductFormScreen._releaseUnusedImages`.
///
/// It used to delete first and upload second, on the theory that a product has
/// one photo so the old one is garbage the moment a new one is picked. Two
/// things are wrong with that. The row is written when the form is *saved*, so
/// picking a photo and then leaving without saving deleted the live photo and
/// left the row pointing at nothing - a product whose image silently became a
/// placeholder, with the file gone and the URL still in the database. And the
/// upload can fail (over the bucket's 5 MiB limit, a rejected MIME type, no
/// network), which destroyed the existing photo in exchange for an error toast.
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

  /// The sources on offer, in order.
  ///
  /// Built per-open rather than fixed: the camera is absent where it would be
  /// a duplicate of the gallery, and "Hapus Foto" only makes sense once there
  /// is a photo. Whatever is in this list is what the sheet returns an index
  /// into.
  List<_ImageSourceAction> get _availableActions => [
        if (AppPlatform.supportsCameraCapture) _ImageSourceAction.camera,
        _ImageSourceAction.gallery,
        if (_imagePath != null) _ImageSourceAction.remove,
      ];

  Future<void> _showImageSourceSheet() async {
    final actions = _availableActions;

    final selected = await ModernBottomSheet.showActions(
      context,
      title: 'Pilih Sumber Foto',
      actions: [
        for (final action in actions)
          ModernBottomSheetAction(
            label: action.label,
            icon: action.icon,
            isDestructive: action == _ImageSourceAction.remove,
          ),
      ],
    );

    if (selected == null || !mounted) return;

    switch (actions[selected]) {
      case _ImageSourceAction.camera:
        await _pickImage(ImageSource.camera);
      case _ImageSourceAction.gallery:
        await _pickImage(ImageSource.gallery);
      case _ImageSourceAction.remove:
        _removeImage();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check and request permission.
      //
      // Only native platforms have a runtime prompt to show. A browser grants
      // camera access through its own UI in response to the picker call, so
      // permission_handler has nothing to ask for and reports a status that
      // would wrongly block the user here.
      if (source == ImageSource.camera && AppPlatform.needsRuntimePermissions) {
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

      // Save and compress the new image.
      //
      // The old object stays where it is. It is still what the row points at
      // until the form saves, and if this upload throws it is still the
      // product's photo.
      //
      // readAsBytes rather than XFile.path: on web the path is a `blob:` URL
      // that no file API can open, while readAsBytes behaves identically on
      // both platforms.
      final savedPath = await _imageService.saveImage(
        PickedImage(
          bytes: await pickedFile.readAsBytes(),
          name: pickedFile.name,
        ),
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

  /// Drops the photo from the form.
  ///
  /// Nothing is removed from storage: the row still references this object, and
  /// will until the form is saved with a null `image_url`. Deleting here is how
  /// a cancelled removal used to leave a product with a dead URL.
  void _removeImage() {
    if (_imagePath == null) return;

    setState(() => _imagePath = null);
    widget.onImageChanged(null);
  }

  Future<void> _showPermissionDeniedDialog(String permissionName) async {
    final openSettings = await ModernDialog.confirm(
      context,
      title: 'Izin Diperlukan',
      message:
          'Untuk menggunakan fitur ini, aplikasi memerlukan akses $permissionName. '
          'Silakan berikan izin melalui pengaturan perangkat.',
      confirmLabel: 'Buka Pengaturan',
      cancelLabel: 'Batal',
    );

    if (openSettings == true) {
      await openAppSettings();
    }
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
