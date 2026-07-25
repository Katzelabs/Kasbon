import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a testable widget wrapped with necessary providers
///
/// This helper wraps the widget with:
/// - [MaterialApp] for Material widgets to work
/// - [ProviderScope] for Riverpod providers
///
/// Example:
/// ```dart
/// await tester.pumpWidget(createTestableWidget(
///   child: ModernButton.primary(child: Text('Test'), onPressed: () {}),
/// ));
/// ```
Widget createTestableWidget({
  required Widget child,
  List<Override>? providerOverrides,
  ThemeData? theme,
  Locale? locale,
  Size? screenSize,
}) {
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? ThemeData.light(),
    locale: locale ?? const Locale('id', 'ID'),
    home: Scaffold(body: child),
  );

  if (screenSize != null) {
    app = MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: app,
    );
  }

  return ProviderScope(
    overrides: providerOverrides ?? [],
    child: app,
  );
}

/// Creates a testable widget without Scaffold wrapper
Widget createTestableWidgetWithoutScaffold({
  required Widget child,
  List<Override>? providerOverrides,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: providerOverrides ?? [],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? ThemeData.light(),
      home: child,
    ),
  );
}

/// Extension on WidgetTester for common test operations
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps the widget and settles with a timeout
  Future<void> pumpAndSettleWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Taps a widget and waits for it to settle
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enters text and waits for it to settle
  Future<void> enterTextAndSettle(Finder finder, String text) async {
    await enterText(finder, text);
    await pumpAndSettle();
  }
}

/// Helper class for testing async operations
class AsyncTestHelper {
  /// Waits for a condition to be true with timeout
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(endTime)) {
      await Future.delayed(pollInterval);
    }
    if (!condition()) {
      throw TimeoutException('Condition not met within timeout');
    }
  }
}

/// Custom exception for test timeouts
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Test matchers for common assertions
class TestMatchers {
  /// Matches a widget that is enabled
  static Matcher isEnabled() => _IsEnabledMatcher();

  /// Matches a widget that is disabled
  static Matcher isDisabled() => _IsDisabledMatcher();
}

class _IsEnabledMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is InkWell) {
      return item.onTap != null;
    }
    if (item is GestureDetector) {
      return item.onTap != null;
    }
    if (item is ElevatedButton) {
      return item.onPressed != null;
    }
    if (item is TextButton) {
      return item.onPressed != null;
    }
    if (item is OutlinedButton) {
      return item.onPressed != null;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('widget is enabled');
  }
}

class _IsDisabledMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is InkWell) {
      return item.onTap == null;
    }
    if (item is GestureDetector) {
      return item.onTap == null;
    }
    if (item is ElevatedButton) {
      return item.onPressed == null;
    }
    if (item is TextButton) {
      return item.onPressed == null;
    }
    if (item is OutlinedButton) {
      return item.onPressed == null;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('widget is disabled');
  }
}

/// Test fixture builder for creating test scenarios
class TestFixtureBuilder<T> {
  final List<T> items = [];

  TestFixtureBuilder<T> add(T item) {
    items.add(item);
    return this;
  }

  TestFixtureBuilder<T> addAll(Iterable<T> newItems) {
    items.addAll(newItems);
    return this;
  }

  List<T> build() => List.unmodifiable(items);
}
