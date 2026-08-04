import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/constants/support_contacts.dart';
import 'package:path/path.dart' as p;

/// The policy URL is a store submission requirement, and a broken one is only
/// discovered by a reviewer.
///
/// `SupportContacts.privacyUrl` is declared in the Play Console and in App
/// Store Connect as well as being a row in Settings, and the page it names is a
/// static file that ships inside the web build. Nothing else connects the two:
/// renaming `web/legal/privacy.html`, or pointing the constant at a tidier
/// path, leaves a link that 404s in three places at once and compiles fine.
void main() {
  /// `web/` as seen from `app/`, which is where `flutter test` runs.
  final webDir = Directory(p.join(Directory.current.path, 'web'));

  File page(String name) => File(p.join(webDir.path, 'legal', name));

  test('the published policy URL points at a file that ships', () {
    final url = Uri.parse(SupportContacts.privacyUrl);

    expect(url.scheme, 'https', reason: 'the stores reject a plain-HTTP URL');

    // The web build copies `web/` verbatim, so the URL path is the file path.
    final hosted = page(p.basename(url.path));
    expect(
      hosted.existsSync(),
      isTrue,
      reason: 'privacyUrl names ${url.path}, but ${p.relative(hosted.path)} '
          'does not exist - the link would 404 for every store reviewer',
    );
  });

  test('both language versions exist and point at each other', () {
    final id = page('privacy.html');
    final en = page('privacy-en.html');

    expect(id.existsSync(), isTrue);
    expect(en.existsSync(), isTrue);

    expect(id.readAsStringSync(), contains('privacy-en.html'));
    expect(en.readAsStringSync(), contains('privacy.html'));
  });

  test('the policy still describes what the app actually does', () {
    final source = page('privacy.html').readAsStringSync();

    // Not a spell-check: these are the four disclosures the audit finding asked
    // for, and each is a fact about the system that could change without anyone
    // thinking to reopen the policy - the retention default, where the data
    // lives, that payment proofs are personal data, and how to get rid of it
    // all.
    expect(source, contains('90 hari'));
    expect(source, contains('Singapura'));
    expect(source, contains('bukti pembayaran'));
    expect(source, contains('support@kasbon.app'));
  });
}
