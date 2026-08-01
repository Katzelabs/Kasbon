import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/app_platform.dart';

/// Where the Supabase session is kept between launches.
///
/// ## What was wrong with the default
///
/// `Supabase.initialize()` with no `authOptions` uses
/// [SharedPreferencesLocalStorage], which on Android is a plaintext XML file in
/// the app sandbox. The sandbox is a real boundary, so on its own that is
/// ordinary - the problem was what sat next to it. `AndroidManifest.xml` did not
/// set `android:allowBackup`, which defaults to **true**, so Android Auto Backup
/// copied that XML to the user's Google Drive. A refresh token that survives a
/// factory reset and lives in a third-party cloud is a different thing from a
/// token in an app sandbox.
///
/// `android:allowBackup="false"` closes the exfiltration path and is the more
/// important half of the fix. This class closes the other half: the token is now
/// encrypted at rest, so reading the file is not the same as having the session.
///
/// `flutter_secure_storage` was already a dependency in `pubspec.yaml` and was
/// imported nowhere - this is what it was presumably added for.
///
/// ## Only Android and iOS, deliberately
///
/// **Web** has no keychain to use. `flutter_secure_storage_web` encrypts into
/// `localStorage` with a key it also keeps in `localStorage`, which is a
/// rearrangement rather than a protection: anything that can read one can read
/// the other. Supabase's own web storage is `localStorage` too, so the honest
/// position is that browser session storage is as safe as the origin, and
/// pretending otherwise would cost a dependency on every page load for nothing.
///
/// **macOS** is excluded for a build reason rather than a security one, and it
/// is worth writing down because the fix looks obvious and is a trap. Reaching
/// the macOS keychain needs the `keychain-access-groups` entitlement, and Xcode
/// refuses to sign a target carrying it with anything less than a real
/// development certificate: "Runner has entitlements that require signing with
/// a development certificate". Ad-hoc signing - what a fresh clone and any
/// unconfigured CI machine get - stops working the moment that key is added, so
/// `flutter run -d macos` breaks for everyone without an Apple developer
/// account. macOS is a development and responsive-testing target here rather
/// than where shops actually run the till, so a plaintext session on it is the
/// cheaper of the two costs. Re-add the entitlement together with real signing,
/// not before.
///
/// That leaves Android and iOS - which is where the finding actually was, since
/// Auto Backup is an Android mechanism.
///
/// ## Existing sessions
///
/// Nothing migrates the old SharedPreferences value across, so anyone holding a
/// session from before this change is signed out once and signs back in. That is
/// acceptable precisely because no release build has ever reached the network -
/// it shipped without the `INTERNET` permission - so the only sessions that can
/// exist are on developer machines.
LocalStorage buildSessionStorage() {
  if (AppPlatform.isMobileOs) {
    return const SecureSessionStorage();
  }
  return SharedPreferencesLocalStorage(
    persistSessionKey: _persistSessionKey,
  );
}

/// Namespaced by bundle id so two Supabase apps on one device cannot collide in
/// the keychain, which is shared per-vendor on Apple platforms.
const String _persistSessionKey = 'supabase.session.com.kasbon.pos';

/// A [LocalStorage] backed by the platform keystore: EncryptedSharedPreferences
/// on Android, Keychain on iOS and macOS, libsecret on Linux, DPAPI on Windows.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // The default on Android is a keystore-wrapped preferences file; the
    // encrypted variant is the one Google actually recommends and it has been
    // stable since plugin v5.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // `unlocked` - the default - would make the session unreadable while the
    // phone is locked. Supabase refreshes tokens on a timer that does not care
    // whether the till is in someone's pocket, so a refresh firing against an
    // unreadable store would sign the cashier out. `first_unlock` keeps it
    // readable after the first unlock since boot, which is the standard choice
    // for a credential the app needs in the background.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() =>
      _storage.containsKey(key: _persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: _persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _persistSessionKey, value: persistSessionString);
}
