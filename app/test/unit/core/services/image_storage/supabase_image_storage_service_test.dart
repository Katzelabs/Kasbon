import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/services/image_storage/supabase_image_storage_service.dart';

/// The public-URL round trip.
///
/// `saveImage` stores what `getPublicUrl` hands back, and `deleteImage` has to
/// get the object path out of that string again. Nothing else in this service
/// can break quietly: an upload failure throws, but a URL parsed wrongly means
/// deletes silently do nothing and images pile up in the bucket.
void main() {
  const bucket = SupabaseImageStorageService.bucketName;
  const userId = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';
  const objectPath = '$userId/prod-42/1690000000000.jpg';

  String publicUrl(String host) => '$host/storage/v1/object/public/'
      '$bucket/$objectPath';

  group('objectPathFromUrl', () {
    test('extracts the object path from a hosted public URL', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          publicUrl('https://abcdefgh.supabase.co'),
        ),
        objectPath,
      );
    });

    test('extracts it from a local development URL', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          publicUrl('http://127.0.0.1:54321'),
        ),
        objectPath,
      );
    });

    test('ignores a query string', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          '${publicUrl('https://abcdefgh.supabase.co')}?t=1690000000000',
        ),
        objectPath,
      );
    });

    test('returns null for a legacy device path', () {
      // What the retired local storage wrote into products.image_url. There is
      // no object behind it, and deleting must be a no-op rather than an error.
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          '/data/user/0/id.kasbon.app/app_flutter/product_images/'
          'prod_42_1690000000000.jpg',
        ),
        isNull,
      );
    });

    test('returns null for a URL in another bucket', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          'https://abcdefgh.supabase.co/storage/v1/object/public/'
          'avatars/$userId/me.jpg',
        ),
        isNull,
      );
    });

    test('returns null for an unrelated http image', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          'https://example.com/photo.jpg',
        ),
        isNull,
      );
    });

    test('returns null when nothing follows the bucket', () {
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          'https://abcdefgh.supabase.co/storage/v1/object/public/$bucket/',
        ),
        isNull,
      );
    });

    test('returns null for a bucket-root object with no user folder', () {
      // Nothing the app writes looks like this - every object is under a user
      // id - so a bare filename means the string is not one of ours.
      expect(
        SupabaseImageStorageService.objectPathFromUrl(
          'https://abcdefgh.supabase.co/storage/v1/object/public/'
          '$bucket/stray.jpg',
        ),
        isNull,
      );
    });

    test('returns null for an empty reference', () {
      expect(SupabaseImageStorageService.objectPathFromUrl(''), isNull);
    });
  });
}
