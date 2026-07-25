import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasbon_pos/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: KasbonApp(),
      ),
    );

    // Just verify the app loads without crashing
    // The full app requires database initialization which is complex for unit tests
    expect(find.byType(KasbonApp), findsOneWidget);
  });
}
