import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/app_platform.dart';
import '../../core/services/image_storage/picked_image.dart';
import '../modern/modern.dart';

export '../../core/services/image_storage/picked_image.dart';

/// Outcome of asking the user for an image.
sealed class ImagePickResult {
  const ImagePickResult();
}

/// They chose a photo.
class ImagePicked extends ImagePickResult {
  const ImagePicked(this.image);
  final PickedImage image;
}

/// They chose to clear the existing photo.
///
/// Distinct from [ImagePickCancelled] because they mean opposite things to a
/// caller holding an image: one says "replace this with nothing", the other
/// says "leave it alone".
class ImagePickCleared extends ImagePickResult {
  const ImagePickCleared();
}

/// They backed out, or the pick failed.
class ImagePickCancelled extends ImagePickResult {
  const ImagePickCancelled();
}

/// Ask the user for an image: camera or gallery, with the permission dance.
///
/// Returns the raw bytes and leaves storage to the caller. That split is what
/// makes this shareable - the POS holds the bytes in memory until a sale
/// commits (the object path needs a transaction id that does not exist yet),
/// while the transaction detail screen uploads immediately. Same picker, two
/// lifetimes.
///
/// [allowClear] adds a destructive "remove" entry, for callers that already
/// hold an image.
///
/// The camera entry is absent where there is no camera. On web
/// `supportsCameraCapture` is false and the gallery entry becomes the browser's
/// file picker.
Future<ImagePickResult> pickImageFromSource(
  BuildContext context, {
  required String title,
  String cameraLabel = 'Kamera',
  String galleryLabel = 'Galeri',
  String clearLabel = 'Hapus Foto',
  bool allowClear = false,
  String permissionSubject = 'kamera',
}) async {
  final sources = <_Source>[
    if (AppPlatform.supportsCameraCapture) _Source.camera,
    _Source.gallery,
    if (allowClear) _Source.clear,
  ];

  final selected = await ModernBottomSheet.showActions(
    context,
    title: title,
    actions: [
      for (final source in sources)
        ModernBottomSheetAction(
          label: switch (source) {
            _Source.camera => cameraLabel,
            _Source.gallery => galleryLabel,
            _Source.clear => clearLabel,
          },
          icon: source.icon,
          isDestructive: source == _Source.clear,
        ),
    ],
  );

  if (selected == null || !context.mounted) {
    return const ImagePickCancelled();
  }

  final source = sources[selected];
  if (source == _Source.clear) return const ImagePickCleared();

  return _pick(
    context,
    source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
    permissionSubject: permissionSubject,
  );
}

enum _Source {
  camera(Icons.camera_alt_outlined),
  gallery(Icons.photo_library_outlined),
  clear(Icons.delete_outline);

  const _Source(this.icon);

  final IconData icon;
}

Future<ImagePickResult> _pick(
  BuildContext context,
  ImageSource source, {
  required String permissionSubject,
}) async {
  try {
    // Only native platforms have a runtime prompt to show. A browser grants
    // camera access through its own UI in response to the picker call, so
    // permission_handler has nothing to ask for and reports a status that would
    // wrongly block the user here.
    if (source == ImageSource.camera && AppPlatform.needsRuntimePermissions) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (context.mounted) {
          await _showPermissionDenied(context, permissionSubject);
        }
        return const ImagePickCancelled();
      }
    }

    // No maxWidth/maxHeight/imageQuality: the picker's own downscale would
    // compound with whatever the caller's storage does, and shrinking twice is
    // how a photographed receipt becomes unreadable. One resize, at the point
    // that knows what the image is for.
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return const ImagePickCancelled();

    return ImagePicked(PickedImage(
      bytes: await picked.readAsBytes(),
      name: picked.name,
    ));
  } catch (e) {
    if (context.mounted) {
      ModernToast.error(context, 'Gagal mengambil foto: ${e.toString()}');
    }
    return const ImagePickCancelled();
  }
}

Future<void> _showPermissionDenied(
  BuildContext context,
  String subject,
) async {
  final openSettings = await ModernDialog.confirm(
    context,
    title: 'Izin Diperlukan',
    message: 'Untuk menggunakan fitur ini, aplikasi memerlukan akses $subject. '
        'Silakan berikan izin melalui pengaturan perangkat.',
    confirmLabel: 'Buka Pengaturan',
    cancelLabel: 'Batal',
  );

  if (openSettings == true) {
    await openAppSettings();
  }
}
