import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Rules that are cheap to break and expensive to notice.
///
/// Every rule here encodes something that already went wrong at least once:
///
/// * The `bottomNavHeight` count grew from 19 to 25 during the reports feature
///   without anyone spotting it, including two sites that forgot the guard
///   entirely and reserve 112px of dead space on tablet.
/// * `injection.dart` named a `dart:io` implementation directly, which dragged
///   the import into the web build transitively and was invisible until the
///   build failed.
/// * ~40 layout decisions read the window rather than their container, which is
///   the whole reason the split views in RESP_07 need a foundation first.
///
/// These are lint rules the analyzer cannot express, so they live as a test.
/// They run in milliseconds and fail with the offending file and line.
void main() {
  final libDir = Directory(p.join(Directory.current.path, 'lib'));

  /// Every Dart file under `lib/`, with its repo-relative path.
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => (
            path: p.relative(f.path, from: Directory.current.path),
            source: f.readAsStringSync(),
          ))
      .toList();

  setUpAll(() {
    // A silently empty file list would make every test below vacuously pass.
    expect(
      dartFiles,
      isNotEmpty,
      reason: 'no Dart files found under lib/ - is the test cwd wrong?',
    );
  });

  /// Report every line matching [pattern], excluding files matching [allow].
  List<String> violations(
    RegExp pattern, {
    bool Function(String path)? allow,
    bool Function(String line)? allowLine,
  }) {
    final found = <String>[];

    for (final file in dartFiles) {
      if (allow != null && allow(file.path)) continue;

      final lines = file.source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Comments describe the rules as often as they break them.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        if (!pattern.hasMatch(line)) continue;
        if (allowLine != null && allowLine(line)) continue;

        found.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    return found;
  }

  group('responsive', () {
    test('features do not read MediaQuery width for layout', () {
      // A feature reading the window cannot work inside a split pane. Use
      // context.breakpoint / context.responsive, which measure the container.
      final found = violations(
        RegExp(r'MediaQuery\.(of\(context\)\.size|sizeOf\(context\))\.width'),
        allow: (path) => !path.contains('lib/features/'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Read the container, not the window:\n${found.join('\n')}',
      );
    });

    test('nothing subtracts bottomNavHeight by hand', () {
      // Use context.shellBottomInset. This is the rule that went from 19 to 25
      // violations unnoticed.
      final found = violations(
        RegExp(r'bottomNavHeight\s*\+|\+\s*AppDimensions\.bottomNavHeight'),
        // The shell owns the bar, so it is allowed to size it.
        allow: (path) => path.endsWith('modern_app_shell.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Use context.shellBottomInset:\n${found.join('\n')}',
      );
    });

    test('the legacy breakpoint constants gain no new readers', () {
      // Only the deprecated forwarders may read these. Everything else uses
      // Breakpoint. Both constants and the forwarders go in RESP_10.
      final found = violations(
        RegExp(r'AppDimensions\.breakpoint(Mobile|Desktop)'),
        allow: (path) =>
            path.endsWith('responsive_utils.dart') ||
            path.endsWith('app_dimensions.dart') ||
            path.endsWith('modern_shell_insets.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Use Breakpoint / context.breakpoint:\n${found.join('\n')}',
      );
    });
  });

  group('platform', () {
    test('dart:io is confined to _io.dart files', () {
      final found = violations(
        RegExp(r"^\s*import\s+'dart:io'"),
        allow: (path) => path.endsWith('_io.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Put it behind a conditional import:\n${found.join('\n')}',
      );
    });

    test('_io implementations are only reached through a conditional export',
        () {
      // The failure RESP_01 hit: injection.dart named LocalImageStorageService
      // directly, so dart:io reached the web build transitively even though
      // every import looked innocent.
      final found = violations(
        RegExp(r"""import\s+'[^']*_io\.dart'"""),
        allow: (path) => path.endsWith('_io.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Import the conditional facade instead:\n${found.join('\n')}',
      );
    });

    test('platform branching goes through AppPlatform', () {
      // Platform.isAndroid and friends only exist on native, and a raw check
      // says what the OS is rather than what the app can do.
      final found = violations(
        RegExp(r'\bPlatform\.(isAndroid|isIOS|isMacOS|isWindows|isLinux)\b'),
        allow: (path) =>
            path.endsWith('_io.dart') || path.endsWith('app_platform.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Use AppPlatform capabilities:\n${found.join('\n')}',
      );
    });

    test('kIsWeb is not used directly outside AppPlatform', () {
      final found = violations(
        RegExp(r'\bkIsWeb\b'),
        allow: (path) => path.endsWith('app_platform.dart'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Add a named capability to AppPlatform:\n${found.join('\n')}',
      );
    });
  });

  group('widget library', () {
    test('no raw fontSize in the Modern library', () {
      // Type scale belongs in AppTextStyles. navLabel was added in RESP_03 to
      // retire the last one of these.
      final found = violations(
        RegExp(r'fontSize:\s*\d'),
        allow: (path) => !path.contains('lib/shared/modern/'),
      );

      expect(
        found,
        isEmpty,
        reason: 'Use an AppTextStyles entry:\n${found.join('\n')}',
      );
    });
  });
}
