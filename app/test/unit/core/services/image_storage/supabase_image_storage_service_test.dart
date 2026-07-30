import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/services/image_storage/supabase_image_storage_service.dart';

/// Normalising a stored reference to an object path.
///
/// `saveImage` stores the path, and everything else - deleting, existence,
/// resolving a URL to render - has to get back to it from whatever a row
/// happens to hold. Two shapes are in the data: the path, and the full public
/// URL that was stored before the host was taken out of it. Nothing else in
/// this service can break quietly: an upload failure throws, but a reference
/// read wrongly means deletes silently do nothing and images pile up in the
/// bucket, or a photo renders as a placeholder with no error.
void main() {
  const bucket = SupabaseImageStorageService.bucketName;
  const userId = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';
  const objectPath = '$userId/prod-42/1690000000000.jpg';

  String publicUrl(String host) => '$host/storage/v1/object/public/'
      '$bucket/$objectPath';

  group('objectPathFrom', () {
    test('passes through the object path a row now holds', () {
      expect(SupabaseImageStorageService.objectPathFrom(objectPath), objectPath);
    });

    test('extracts the object path from a hosted public URL', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          publicUrl('https://abcdefgh.supabase.co'),
        ),
        objectPath,
      );
    });

    test('extracts it from a local development URL', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          publicUrl('http://127.0.0.1:54321'),
        ),
        objectPath,
      );
    });

    test('ignores a query string', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          '${publicUrl('https://abcdefgh.supabase.co')}?t=1690000000000',
        ),
        objectPath,
      );
    });

    test('returns null for a legacy device path', () {
      // What the retired local storage wrote into products.image_url. There is
      // no object behind it, and deleting must be a no-op rather than an error.
      expect(
        SupabaseImageStorageService.objectPathFrom(
          '/data/user/0/id.kasbon.app/app_flutter/product_images/'
          'prod_42_1690000000000.jpg',
        ),
        isNull,
      );
    });

    test('returns null for a URL in another bucket', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          'https://abcdefgh.supabase.co/storage/v1/object/public/'
          'avatars/$userId/me.jpg',
        ),
        isNull,
      );
    });

    test('returns null for an unrelated http image', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          'https://example.com/photo.jpg',
        ),
        isNull,
      );
    });

    test('returns null when nothing follows the bucket', () {
      expect(
        SupabaseImageStorageService.objectPathFrom(
          'https://abcdefgh.supabase.co/storage/v1/object/public/$bucket/',
        ),
        isNull,
      );
    });

    test('returns null for a bucket-root object with no user folder', () {
      // Nothing the app writes looks like this - every object is under a user
      // id - so a bare filename means the string is not one of ours.
      expect(
        SupabaseImageStorageService.objectPathFrom(
          'https://abcdefgh.supabase.co/storage/v1/object/public/'
          '$bucket/stray.jpg',
        ),
        isNull,
      );
    });

    test('returns null for an empty reference', () {
      expect(SupabaseImageStorageService.objectPathFrom(''), isNull);
    });

    test('returns null for a bare filename with no folder', () {
      // Same rule as the URL case: every object is under a user id, so this is
      // not a reference of ours and must not be resolved against the bucket.
      expect(SupabaseImageStorageService.objectPathFrom('stray.jpg'), isNull);
    });

    test('ignores a query string on a bare path', () {
      expect(
        SupabaseImageStorageService.objectPathFrom('$objectPath?t=1'),
        objectPath,
      );
    });
  });
}
