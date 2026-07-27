import 'image_storage_service.dart';
import 'local_image_storage_service.dart';

/// Native platforms store product images on the device filesystem.
///
/// Note this is why product images have never synced across devices: the path
/// returned here is local to one phone. RESP_02 fixes that.
ImageStorageService createImageStorageService() => LocalImageStorageService();
