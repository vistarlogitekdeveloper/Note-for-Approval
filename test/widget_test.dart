import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:note_approval/main.dart';

void main() {
  testWidgets('Smoke test NFA app boot', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: VistarApp()));

    // Verify splash screen or login route starts up
    expect(find.byType(VistarApp), findsOneWidget);
  });
}
