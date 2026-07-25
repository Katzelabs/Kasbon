import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App info state
class AppInfo {
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  const AppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  String get fullVersion => '$version ($buildNumber)';
}

/// Provider for app info
final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();

  return AppInfo(
    appName: packageInfo.appName,
    packageName: packageInfo.packageName,
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
});
