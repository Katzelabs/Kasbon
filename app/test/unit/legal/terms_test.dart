import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/constants/support_contacts.dart';
import 'package:path/path.dart' as p;

/// The same guard as `privacy_policy_test.dart`, for the terms.
///
/// This one exists because the failure already happened: `termsUrl` pointed at
/// `https://kasbon.app/terms` for as long as the row existed in *Tentang
/// Aplikasi → Legal*, and nothing ever served that path. A constant naming a
/// page nobody wrote compiles, analyses and ships.
void main() {
  final webDir = Directory(p.join(Directory.current.path, 'web'));

  File page(String name) => File(p.join(webDir.path, 'legal', name));

  test('the terms URL points at a file that ships', () {
    final url = Uri.parse(SupportContacts.termsUrl);

    expect(url.scheme, 'https');

    final hosted = page(p.basename(url.path));
    expect(
      hosted.existsSync(),
      isTrue,
      reason: 'termsUrl names ${url.path}, but ${p.relative(hosted.path)} does '
          'not exist - the Legal row in Tentang Aplikasi would 404',
    );
  });

  test('both language versions exist and point at each other', () {
    final id = page('terms.html');
    final en = page('terms-en.html');

    expect(id.existsSync(), isTrue);
    expect(en.existsSync(), isTrue);

    expect(id.readAsStringSync(), contains('terms-en.html'));
    expect(en.readAsStringSync(), contains('terms.html'));
  });

  test('the terms cross-link to the privacy policy', () {
    // The two documents form one agreement and each says so; a broken link
    // between them is the one a reader follows and does not find.
    expect(page('terms.html').readAsStringSync(), contains('privacy.html'));
    expect(
      page('terms-en.html').readAsStringSync(),
      contains('privacy-en.html'),
    );
  });

  test('the terms still describe the service the app actually is', () {
    final source = page('terms.html').readAsStringSync();

    // Four load-bearing statements, each of which stops being true if the
    // product changes: no payment processing, cloud-only so it needs a
    // connection, free today, and proofs that delete themselves.
    expect(source, contains('tidak memproses pembayaran'));
    expect(source, contains('memerlukan koneksi internet'));
    expect(source, contains('tanpa biaya'));
    expect(source, contains('90 hari'));
  });
}
