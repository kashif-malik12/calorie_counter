// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_fit/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const CalorieFitApp());
    expect(find.textContaining('Today'), findsOneWidget);
  });
}
