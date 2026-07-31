import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/shared/providers/shell_account_provider.dart';
import 'package:kasbon_pos/shared/providers/user_provider.dart';

/// Stands in for the Supabase session, so a test can switch accounts without
/// one.
final _signedIn = StateProvider<UserInfo>((ref) => UserInfo.signedOut);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      userInfoProvider.overrideWith((ref) => ref.watch(_signedIn)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('shellAccountProvider', () {
    test('is null when nobody is signed in', () {
      expect(_container().read(shellAccountProvider), isNull);
    });

    test('names the signed-in account', () {
      final container = _container();
      container.read(_signedIn.notifier).state =
          const UserInfo(name: 'Budi Santoso', email: 'budi@toko.id');

      final account = container.read(shellAccountProvider);

      expect(account?.name, 'Budi Santoso');
      expect(account?.email, 'budi@toko.id');
      expect(account?.initials, 'BS');
    });

    // The bug this provider was rewritten for: it read `currentUser` once and
    // cached it, so the rail's footer kept naming whoever signed in first no
    // matter who signed in after them.
    test('follows a switch to another account', () {
      final container = _container();
      container.read(_signedIn.notifier).state =
          const UserInfo(name: 'Budi', email: 'budi@toko.id');
      expect(container.read(shellAccountProvider)?.name, 'Budi');

      container.read(_signedIn.notifier).state =
          const UserInfo(name: 'Siti', email: 'siti@warung.id');

      expect(container.read(shellAccountProvider)?.name, 'Siti');
      expect(container.read(shellAccountProvider)?.email, 'siti@warung.id');
    });

    test('goes back to null on sign-out', () {
      final container = _container();
      container.read(_signedIn.notifier).state =
          const UserInfo(name: 'Budi', email: 'budi@toko.id');
      expect(container.read(shellAccountProvider), isNotNull);

      container.read(_signedIn.notifier).state = UserInfo.signedOut;

      expect(container.read(shellAccountProvider), isNull);
    });
  });
}
