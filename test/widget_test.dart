import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenvi/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: ZerviApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
