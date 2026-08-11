import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/constants/support_contacts.dart';
import 'package:path/path.dart' as p;

/// The deletion URL is a store submission requirement, and a broken one is
/// only discovered by a reviewer.
///
/// Play requires *two* routes to account deletion - one inside the app and one
/// on the web - and checks the web one resolves. `SupportContacts
/// .accountDeletionUrl` is what goes in the Play Console; the page it names is
/// a static file inside the web build. Nothing else connects the two, exactly
/// as with the privacy policy: renaming the file leaves a link that 404s for
/// every reviewer and compiles fine.
void main() {
  /// `web/` as seen from `app/`, which is where `flutter test` runs.
  final webDir = Directory(p.join(Directory.current.path, 'web'));

  File page(String name) => File(p.join(webDir.path, 'legal', name));

  test('the published deletion URL points at a file that ships', () {
    final url = Uri.parse(SupportContacts.accountDeletionUrl);

    expect(url.scheme, 'https', reason: 'the stores reject a plain-HTTP URL');

    final hosted = page(p.basename(url.path));
    expect(
      hosted.existsSync(),
      isTrue,
      reason: 'accountDeletionUrl names ${url.path}, but '
          '${p.relative(hosted.path)} does not exist - the link would 404 for '
          'every store reviewer',
    );
  });

  test('both language versions exist and point at each other', () {
    final id = page('hapus-akun.html');
    final en = page('hapus-akun-en.html');

    expect(id.existsSync(), isTrue);
    expect(en.existsSync(), isTrue);

    expect(id.readAsStringSync(), contains('hapus-akun-en.html'));
    expect(en.readAsStringSync(), contains('hapus-akun.html'));
  });

  test('the page still describes the flow the app actually implements', () {
    final source = page('hapus-akun.html').readAsStringSync();

    // Not a spell-check. Each of these is a fact about the running system that
    // could change without anyone thinking to reopen the page: where the row
    // lives, the two gates on the dialog, the 24h orphan sweep that backs up a
    // failed storage delete, and the email fallback for someone locked out.
    expect(source, contains('Hapus Akun'));
    expect(source, contains('password'));
    expect(source, contains('HAPUS'));
    expect(source, contains('24 jam'));
    expect(source, contains(SupportContacts.supportEmail));
  });

  test('the English page names the same in-app labels, untranslated', () {
    final source = page('hapus-akun-en.html').readAsStringSync();

    // A reviewer following this page is looking at an app whose UI is entirely
    // in Bahasa Indonesia. Translating "Pengaturan → Akun → Hapus Akun" into
    // English gives them three labels that appear nowhere on screen.
    expect(source, contains('Pengaturan'));
    expect(source, contains('Hapus Akun'));
    expect(source, contains('HAPUS'));
  });
}
